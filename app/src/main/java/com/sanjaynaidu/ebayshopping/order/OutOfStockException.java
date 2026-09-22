/*
 * =============================================================================
 * Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
 * Author  : Sanjay Naidu
 * File    : order/OutOfStockException.java
 * =============================================================================
 */
package com.sanjaynaidu.ebayshopping.order;

public class OutOfStockException extends RuntimeException {

    public OutOfStockException(String productName, int requested, int available) {
        super("Only " + available + " unit(s) of '" + productName + "' available, " + requested + " requested");
    }
}
