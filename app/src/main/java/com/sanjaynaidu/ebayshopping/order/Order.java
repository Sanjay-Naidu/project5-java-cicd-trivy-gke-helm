/*
 * =============================================================================
 * Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
 * Author  : Sanjay Naidu
 * File    : order/Order.java - a priced, confirmed order
 * =============================================================================
 */
package com.sanjaynaidu.ebayshopping.order;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

public record Order(
        String orderId,
        Instant createdAt,
        String customerName,
        List<Item> items,
        BigDecimal subtotal,
        BigDecimal shipping,
        BigDecimal total,
        String servedBy) {

    public record Item(
            long productId,
            String name,
            BigDecimal unitPrice,
            int quantity,
            BigDecimal lineTotal) {
    }
}
