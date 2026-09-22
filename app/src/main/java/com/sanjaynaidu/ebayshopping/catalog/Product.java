/*
 * =============================================================================
 * Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
 * Author  : Sanjay Naidu
 * File    : catalog/Product.java - immutable product model
 * =============================================================================
 */
package com.sanjaynaidu.ebayshopping.catalog;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * A catalog item. BigDecimal for money - never double, which cannot represent
 * values like 0.10 exactly and drifts when totals are summed.
 */
public record Product(
        long id,
        String name,
        String category,
        String description,
        BigDecimal price,
        BigDecimal listPrice,
        double rating,
        int stock,
        String icon) {

    public boolean inStock() {
        return stock > 0;
    }

    /** Percentage saved against the list price, rounded down (0 if no discount). */
    public int discountPercent() {
        if (listPrice == null || listPrice.compareTo(price) <= 0) {
            return 0;
        }
        return listPrice.subtract(price)
                .multiply(BigDecimal.valueOf(100))
                .divide(listPrice, 0, RoundingMode.DOWN)
                .intValue();
    }
}
