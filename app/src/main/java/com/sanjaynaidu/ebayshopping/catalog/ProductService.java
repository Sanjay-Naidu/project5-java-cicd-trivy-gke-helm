/*
 * =============================================================================
 * Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
 * Author  : Sanjay Naidu
 * File    : catalog/ProductService.java - search, filter, lookup
 * =============================================================================
 */
package com.sanjaynaidu.ebayshopping.catalog;

import java.util.List;
import java.util.Locale;
import org.springframework.stereotype.Service;

@Service
public class ProductService {

    private final ProductRepository repository;

    public ProductService(ProductRepository repository) {
        this.repository = repository;
    }

    /**
     * Products matching an optional free-text query and optional category.
     * Blank/null filters are ignored, so search("", null) returns everything.
     */
    public List<Product> search(String query, String category) {
        String q = query == null ? "" : query.trim().toLowerCase(Locale.ROOT);
        return repository.findAll().stream()
                .filter(p -> category == null || category.isBlank() || p.category().equalsIgnoreCase(category))
                .filter(p -> q.isEmpty()
                        || p.name().toLowerCase(Locale.ROOT).contains(q)
                        || p.description().toLowerCase(Locale.ROOT).contains(q))
                .toList();
    }

    public Product getById(long id) {
        return repository.findById(id).orElseThrow(() -> new ProductNotFoundException(id));
    }

    public List<String> categories() {
        return repository.findAll().stream().map(Product::category).distinct().sorted().toList();
    }
}
