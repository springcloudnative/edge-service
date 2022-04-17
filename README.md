# Defining routes and predicates
Spring Cloud Gateway provides three main building blocks:
* **Route**. It’s identified by a unique ID, a collection of predicates deciding whether to follow the route, a URI for forwarding the request if the predicates allow, and a
collection of filters applied either before or after forwarding the request downstream.

* **Predicate**. It matches anything from the HTTP request, including path, host, headers, query parameters, cookies, and body.

* **Filter**. It modifies an HTTP request or response before or after forwarding the request to the downstream service.