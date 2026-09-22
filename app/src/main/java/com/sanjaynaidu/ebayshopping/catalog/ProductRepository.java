/*
 * =============================================================================
 * Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
 * Author  : Sanjay Naidu
 * File    : catalog/ProductRepository.java - in-memory catalog
 * =============================================================================
 * WHY in-memory: the point of this project is the delivery platform, not the
 * database. A read-only seeded catalog keeps every pod identical and
 * stateless, so the HPA can add/remove replicas freely. Swapping this class
 * for a Spring Data repository backed by Cloud SQL is the first roadmap item.
 */
package com.sanjaynaidu.ebayshopping.catalog;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Repository;

@Repository
public class ProductRepository {

    private static final List<Product> PRODUCTS = List.of(
            product(1, "Wireless Noise-Cancelling Headphones", "Electronics",
                    "Over-ear Bluetooth headphones with 40-hour battery and active noise cancellation.",
                    "7999", "12999", 4.6, 25, "🎧"),
            product(2, "Smartphone 5G - 128 GB", "Electronics",
                    "6.5-inch AMOLED display, 50 MP triple camera, 5000 mAh battery.",
                    "18999", "21999", 4.4, 40, "📱"),
            product(3, "Ultrabook Laptop 14 inch", "Electronics",
                    "Lightweight 14-inch laptop, 16 GB RAM, 512 GB SSD, all-day battery.",
                    "58990", "69990", 4.5, 10, "💻"),
            product(4, "Smart Watch Series 3", "Electronics",
                    "Heart-rate, SpO2 and sleep tracking with 7-day battery life.",
                    "3499", "4999", 4.1, 60, "⌚"),
            product(5, "Men's Running Shoes", "Fashion",
                    "Breathable mesh upper with cushioned sole for daily runs.",
                    "2499", "3999", 4.3, 35, "👟"),
            product(6, "Classic Denim Jacket", "Fashion",
                    "Stone-washed cotton denim jacket, regular fit.",
                    "1899", "2999", 4.2, 20, "🧥"),
            product(7, "Leather Wallet", "Fashion",
                    "Genuine leather bi-fold wallet with RFID protection.",
                    "799", "1299", 4.5, 80, "👛"),
            product(8, "Non-Stick Cookware Set (5 pc)", "Home & Kitchen",
                    "Induction-ready non-stick pans and kadhai with glass lids.",
                    "2999", "4499", 4.4, 15, "🍳"),
            product(9, "Espresso Coffee Maker", "Home & Kitchen",
                    "15-bar pump espresso machine with milk frother.",
                    "8499", "10999", 4.3, 8, "☕"),
            product(10, "LED Desk Lamp", "Home & Kitchen",
                    "Dimmable desk lamp with USB charging port and 3 colour modes.",
                    "1199", "1599", 4.0, 50, "💡"),
            product(11, "The DevOps Handbook", "Books",
                    "How to create world-class agility, reliability and security in technology organisations.",
                    "899", "1199", 4.8, 30, "📘"),
            product(12, "Kubernetes Up and Running", "Books",
                    "A practical guide to deploying and operating applications on Kubernetes.",
                    "1299", "1599", 4.7, 0, "📗"));

    public List<Product> findAll() {
        return PRODUCTS;
    }

    public Optional<Product> findById(long id) {
        return PRODUCTS.stream().filter(p -> p.id() == id).findFirst();
    }

    private static Product product(long id, String name, String category, String description,
            String price, String listPrice, double rating, int stock, String icon) {
        return new Product(id, name, category, description,
                new BigDecimal(price), new BigDecimal(listPrice), rating, stock, icon);
    }
}
