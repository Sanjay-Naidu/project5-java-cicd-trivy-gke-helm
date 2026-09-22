/*
 * =============================================================================
 * Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
 * Author  : Sanjay Naidu
 * File    : EbayShoppingApplication.java - Spring Boot entry point
 * =============================================================================
 */
package com.sanjaynaidu.ebayshopping;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class EbayShoppingApplication {

    public static void main(String[] args) {
        SpringApplication.run(EbayShoppingApplication.class, args);
    }
}
