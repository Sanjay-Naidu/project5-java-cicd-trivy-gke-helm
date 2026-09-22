/*
 * =============================================================================
 * Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
 * Author  : Sanjay Naidu
 * File    : config/AppProperties.java - typed app settings (12-factor config)
 * =============================================================================
 * Values come from environment variables injected by the Helm chart:
 *   APP_VERSION     -> the immutable image tag (sha-<commit>) set by CD
 *   APP_ENVIRONMENT -> dev / prod, from the per-environment values file
 * Showing both in the UI and on /api/info proves which build runs where.
 */
package com.sanjaynaidu.ebayshopping.config;

import java.math.BigDecimal;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app")
public record AppProperties(
        String name,
        String version,
        String environment,
        BigDecimal freeShippingThreshold,
        BigDecimal shippingFee) {
}
