/*
 * =============================================================================
 * Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
 * Author  : Sanjay Naidu
 * File    : api/ProductApiController.java - read-only catalog REST API
 * =============================================================================
 */
package com.sanjaynaidu.ebayshopping.api;

import com.sanjaynaidu.ebayshopping.catalog.Product;
import com.sanjaynaidu.ebayshopping.catalog.ProductService;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class ProductApiController {

    private final ProductService productService;

    public ProductApiController(ProductService productService) {
        this.productService = productService;
    }

    @GetMapping("/products")
    public List<Product> products(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String category) {
        return productService.search(q, category);
    }

    @GetMapping("/products/{id}")
    public Product product(@PathVariable long id) {
        return productService.getById(id);
    }

    @GetMapping("/categories")
    public List<String> categories() {
        return productService.categories();
    }
}
