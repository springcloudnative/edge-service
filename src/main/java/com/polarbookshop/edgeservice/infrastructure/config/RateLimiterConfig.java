package com.polarbookshop.edgeservice.infrastructure.config;

import org.springframework.cloud.gateway.filter.ratelimit.KeyResolver;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import reactor.core.publisher.Mono;

/**
 * This configuration class is used to define
 * a strategy to resolve the bucket to use for each
 * request.
 */
@Configuration
public class RateLimiterConfig {

    @Bean
    public KeyResolver keyResolver() {
        // Rate limiting is applied to requests using a constant key
        return exchange -> Mono.just("ANONYMOUS");
    }
}
