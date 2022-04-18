# Defining routes and predicates
Spring Cloud Gateway provides three main building blocks:
* **Route**. It’s identified by a unique ID, a collection of predicates deciding whether to follow the route, a URI for forwarding the request if the predicates allow, and a
collection of filters applied either before or after forwarding the request downstream.

* **Predicate**. It matches anything from the HTTP request, including path, host, headers, query parameters, cookies, and body.

* **Filter**. It modifies an HTTP request or response before or after forwarding the request to the downstream service.

It’s essential to configure a timeout to make it resilient to inter-process communication failures. Spring Cloud Gateway provides dedicated properties to configure the
HTTP client timeouts.
In the **application.yml** define values for the connection timeout (the time limit for a connection to be established with the downstream service) and for
the response timeout (time limit for a response to be received).
```
cloud:
  gateway:
    httpclient:             
      connect-timeout: 5000
      response-timeout: 5s
```
By default, the Netty HTTP client used by Spring Cloud Gateway is configured with an *elastic* connection pool to increase the number of concurrent connections dynamically as the workload
increases. Depending on the number of requests your system will receive simultaneously, you might want to switch to a *fixed* connection pool to have more control over the number of
connections. You can configure the Netty connection pool in Spring Cloud Gateway through the **spring.cloud.gateway.httpclient.pool** property group.
```
pool:
  type: elastic
  max-idle-time: 15s 
  max-life-time: 60s
```

# Processing requests and responses through filters
Routes and predicates alone make the application act as a proxy, but filters make Spring Cloud Gateway really powerful. Filters can run before forwarding incoming requests to a downstream
application (**pre-filters**). For example, they’re used for:
* manipulating the request headers;
* applying rate limiting and circuit breaking;
* defining retries and timeouts for the proxied request;
* triggering an authentication flow with OAuth2 and OpenID Connect.

Other filters can apply to outgoing responses before sending them back to the client and after being received from the downstream application (post-filters). For example, they’re used for:
* setting security headers;
* manipulating the response body to remove sensitive information.

## Using the retry filter (application.yml)
Let’s define a maximum of 3 retry attempts for all GET requests whenever the error is in the *5xx* range (*SERVER_ERROR*). You don’t want to retry requests when the error is in the *4xx* range. For
example, if the result is a *404* response, it doesn’t make sense to retry the request. You can also list the exceptions for which a retry should be attempted, for example, *IOException* and
*TimeoutException*.
**The retry pattern is useful when a downstream service is momentarily unavailable**.
```
    gateway:
      default-filters:
        - name: Retry
          args:
            retries: 3
            methods: GET
            series: SERVER_ERROR
            exceptions: java.io.IOException, java.util.concurrent.TimeoutException
            backoff:
              firstBackoff: 50ms
              maxBackoff: 500ms
              factor: 2
              basedOnPreviousValue: false
```
# Fault tolerance with Spring Cloud Circuit Breaker and Resilience4J
The circuit breaker pattern comes in handy if a downstream service stays down for more than a few instants. At that point, we could directly stop forwarding
request to it until we're sure that it's back. Keeping sending requests wouldn't be beneficial for the caller nor the callee.
**One of the principles for achieving resilience is blocking a failure from cascading and affecting other components.**
In the world of distributed systems, you can establish circuit breakers at the integration points between the components.
In a typical scenario, the circuit is *closed**, meaning that the services can interact over the network. For each server error response returned by a MS, the circuit breaker in the edge service would register the
failure. When the number of failures exceeds a certain threshold, the circuit breaker trips, and the circuit transitions to **open**.
While the circuit is open, communications between the edge service and the MS in failure are not allowed. Any request that should be forwarded to that MS will fail right away.
In this state, either an error is returned to the client, or fallback logic is executed. After an appropriate amount of time, the circuit breaker transitions to a **half-open** state, which allows the next call to
the MS in failure to go through. If it succeeds, then the circuit breaker is reset, and transitions to **closed**. Otherwise, it goes back to being **open**.

In the worst-case scenario, like when a circuit breaker trips, you should guarantee a graceful degradation. You can adopt different strategies for the fallback method. For
example, you might decide to return a default value or the last available value from a cache in case of a GET request.

## Introducing circuit breakers with Spring Cloud Circuit Breaker (application.yml)
**org.springframework.cloud:spring-cloud-starter-circuitbreaker-reactor-resilience4j** (pom.xml)
```
    gateway:
      routes:
        - id: catalog-route
          uri: ${CATALOG_SERVICE_URL:http://localhost:9001}/books
          predicates:
            - Path=/books/**
          filters:
            - name: CircuitBreaker
              args:
                name: catalogCircuitBreaker
                fallbackUri: forward:/catalog-fallback
        - id: order-route
          uri: ${ORDER_SERVICE_URL:http://localhost:9002}/orders
          predicates:
            - Path=/orders/**
          filters:
            - name: CircuitBreaker
              args:
                name: orderCiruitBreaker
```
The **CircuitBreaker** filter in Spring Cloud Gateway relies on Spring Cloud Circuit Breaker to wrap a route. Being a *GatewayFilter*, you can apply it to specific routes or define it as a default
filter. Let’s go with the first option. You can also specify an optional fallback URI to forward the request when the circuit is in an open state.

## Configuring a circuit breaker with Resilience4J(application.yml)
After defining to which routes apply the **CircuitBreaker** filter, you need to configure the circuit breakers themselves. As often in Spring Boot, you have two main choices. You can
configure circuit breakers through the properties provided by Resilience4J or via a *Customizer* bean. 
Since we’re using the reactive version of Resilience4J, it would be a *Customizer<ReactiveResilience4JCircuitBreakerFactory>*.
```
resilience4j:
  circuitbreaker:
    configs:
      default:
        slidingWindowsSize: 20
        permittedNumberOfCallsInHalfOpenState: 5
        failureRateThreshold: 50
        waitDurationInOpenState: 15000
  timelimiter:
    configs:
      default:
        timeoutDuration: 5s
```
For the current example, we can define circuit breakers to consider a window of 20 calls (**slidingWindowSize**). Each new call will make the window move, dropping the oldest
registered call. When at least 50% of the calls in the window produced an error (**failureRateThreshold**), the circuit breaker trips, and the circuit enters the open state. After 15
seconds (**waitDurationInOpenState**), the circuit is allowed to transition to a half-open state in which 5 calls are permitted (**permittedNumberOfCallsInHalfOpenState**). If at least 50% of
them result in an error, the circuit will go back to the open state. Otherwise, the circuit breaker trips to the close state.

The timeout configured via Resilience4J will take precedence over the response timeout for the Netty HTTP client (**spring.cloud.gateway.httpclient.response-timeout**).

## Defining fallback REST APIs with Spring WebFlux
WebFlux supports defining REST endpoints both using @RestController classes and Router Functions. Let’s use the functional way for declaring the
fallback endpoints.
Functional endpoints in Spring WebFlux are defined as routes in a **RouterFunction<ServerResponse>** bean, using the fluent API provided by *RouterFunctions*. 
For each route, you need to define the endpoint URL, a method, and a handler.

## Combining circuit breakers, retries, and time limiters
When you combine multiple resilience patterns, the sequence in which they are applied is fundamental. Spring Cloud Gateway takes care of applying the **TimeLimiter** first (or the
timeout on the HTTP client), then the **CircuitBreaker** filter, and finally **Retry**.
You can verify the result of applying these patterns to Edge Service using a tool like Apache Benchmark.
Make sure your downstream services are down and see what happens, if for instance, you run 21 sequential POST requests (-n 21 -c 1 -m POST) to one of the
endpoints (/orders).
```
ab -n 21 -c 1 -m POST http://localhost:9000/orders
```
or
``` 
ab -n 21 -c 1 -m GET http://localhost:9000/books
```

# Rate limiting with Spring Cloud Gateway and Redis
Rate limiting is a pattern used to control the rate of traffic sent to or received from an application, helping to make your system more resilient and robust. In the context of HTTP interactions, you
can apply this pattern to control outgoing or incoming network traffic using client-side and server-side rate limiters, respectively.

**Client-side rate limiters** are for constraining the number of requests sent to a downstream service in a given period. It’s a useful pattern to adopt when third-party organizations like cloud
providers manage and offer the downstream service. You want to avoid incurring extra costs for having sent more requests than the ones allowed by your subscription. In case of pay-per-use
services, it helps prevent unexpected expenses.

**Server-side rate limiters** are for constraining the number of requests received by an upstream service (or client) in a given period. This pattern is handy when implemented in an API gateway
to protect the whole system from overloading or DoS attacks.
When a user has exceeded the number of allowed requests in a specific time window, all the extra requests are rejected with an HTTP 429 - Too Many Requests status. The limit is applied
according to a given strategy. For example, you can limit requests per session, per IP address, per user, or per tenant. The overall goal is to keep the system available for all users in case of
adversities. That is the definition of resilience.

Resilience4J supports the client-side rate limiter and bulkhead patterns for both reactive and non-reactive applications. Spring Cloud Gateway supports the server-side rate limiter pattern.
Let's see how to use the server-side rate limiter pattern for the Edge Service using Spring Cloud Gateway and **Spring Data Redis Reactive**.

## Running Redis as a container (docker-compose.yml)
Redis can be used as a dedicated service to store the rate-limiting state and make it available to all the application replicas.
Redis is an in-memory store that is commonly used as a cache, message broker, or database. In Edge Service, you’re going to use it as the data service backing the request limiter
implementation provided by Spring Cloud Gateway. The Spring Data Reactive Redis project provides the integration between a Spring Boot application and Redis.
```
  polar-redis:
    image: redis:6.2
    container_name: polar-redis
    ports:
      - 6379:6379
```

## Integrating Spring with Redis (pom.xml && application.yml)
To add **org.springframework.boot:spring-boot-starter-data-redis-reactive**

In the *application.yml* file, you can configure the Redis integration through the properties provided by Spring Boot. Besides **spring.redis.host** and **spring.redis.port** for
defining where to reach Redis, you can also specify connection and read timeouts using **spring.redis.connect-timeout** and **spring.redis.timeout** respectively.
```
spring:
  redis:
    connec-timeout: 2s
    host: ${REDIS_HOST:localhost}
    port: 6379
    timeout: 1s
```

## Using the RequestRateLimiter filter with Redis
Depending on the requirements, you can configure the RequestRateLimiter filter for specific routes or as a default filter.
The implementation of **RequestRateLimiter** on Redis is based on the *token bucket algorithm*. Each user is assigned a bucket inside which tokens are dripped overtime at a specific rate (
*replenish rate*). Each bucket has a maximum capacity (*burst capacity*). When a user makes a request, a token is removed from its bucket. When there are no more tokens left, the request is
not permitted, and the user will have to wait that more tokens are dripped into its bucket.
You can allow temporary bursts by defining a larger capacity for the bucket (*redis-rate-limiter.burstCapacity*), for example, 20.
t means that when a spike occurs, up to 20 requests are allowed per second. Since the replenish rate is lower than the burst capacity, subsequent bursts are not allowed.
```
spring:
  cloud:
    gateway:
      default-filters:
        - name: RequestRateLimiter
          args:
            redis-rate-limiter.replenishRate: 10
            redis-rate-limiter.burstCapacity: 20
            redis-rate-limiter.requestedTokens: 1
```

The RequestRateLimiter filter relies on a KeyResolver bean to derive the bucket to use per request. By default, it uses the currently authenticated user in Spring Security. You can define
your own KeyResolver bean and make it return a constant value (for example, ANONYMOUS) so that any request will be mapped to the same bucket.
In your Edge Service project, create a new **RateLimiterConfig** class and declare a **KeyResolver** bean implementing a strategy to return a constant key.

# Distributed session management with Redis

## Handling sessions with Spring Session Data Redis (pom.xml && application.yml)
- Add the **org.springframework.session:spring-session-data-redis** dependency.

A fundamental reason for using a distributed session store is that you usually have multiple instances for the same application. You want them to access the same session data to provide a
seamless experience to the user.
Redis is a popular option for session management and is supported by Spring Session Data Redis. Furthermore, you have already set it up for the rate limiters. You can add it to Edge
Service with minimal configuration.

- Instruct Spring Boot to use Redis for session management (**spring.session.store-type**) and define a unique namespace to prefix all session data
  coming from Edge Service (**spring.session.redis.namespace**). You can also define a timeout for the session (**spring.session.timeout**). If you don’t specify any, the default is 30
  minutes.
```
spring:
  session:
    store-type: redis
    timeout: 10m
    redis:
      namespace: polar:edge
```