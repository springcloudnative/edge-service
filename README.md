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