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