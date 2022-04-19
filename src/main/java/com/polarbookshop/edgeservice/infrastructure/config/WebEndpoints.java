package com.polarbookshop.edgeservice.infrastructure.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.web.reactive.function.server.RouterFunction;
import org.springframework.web.reactive.function.server.RouterFunctions;
import org.springframework.web.reactive.function.server.ServerResponse;
import reactor.core.publisher.Mono;

/**
 * This class is used to configure fallback endpoints for when the
 * Catalog Service is unavailable.
 * For each route, the endpoint URL, a method and a handler must be
 * defined.
 */
@Configuration
public class WebEndpoints {

    /**
     * Functional endpoints are defined in a bean.
     * - A fallback response is defined to be used to handle
     *   the GET endpoint, returning an empty string.
     * - A fallback response is defined to be used to handle
     *   the POST endpoint, returning an HTTP 503 error.
     * @return
     */
    @Bean
    public RouterFunction<ServerResponse> routerFunction() {
        // Offers a fluent API to build routes
        return RouterFunctions.route()
                .GET("/catalog-fallback", request ->
                        ServerResponse.ok()
                                .body(Mono.just(""), String.class))
                .POST("/catalog-fallback", request ->
                        ServerResponse.status(HttpStatus.SERVICE_UNAVAILABLE).build())
                .build();
    }
}
