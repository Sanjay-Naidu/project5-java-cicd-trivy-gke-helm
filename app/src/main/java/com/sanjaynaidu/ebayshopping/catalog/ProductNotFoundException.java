/*
 * =============================================================================
 * Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
 * Author  : Sanjay Naidu
 * File    : catalog/ProductNotFoundException.java
 * =============================================================================
 */
package com.sanjaynaidu.ebayshopping.catalog;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/** 404 for the HTML pages (renders templates/error/404.html); the API maps it to a ProblemDetail. */
@ResponseStatus(HttpStatus.NOT_FOUND)
public class ProductNotFoundException extends RuntimeException {

    public ProductNotFoundException(long id) {
        super("Product " + id + " not found");
    }
}
