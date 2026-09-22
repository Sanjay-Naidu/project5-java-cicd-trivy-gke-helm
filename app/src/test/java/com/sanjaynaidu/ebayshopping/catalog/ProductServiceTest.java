/*
 * =============================================================================
 * Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
 * Author  : Sanjay Naidu
 * File    : catalog/ProductServiceTest.java - plain unit tests, no Spring
 * =============================================================================
 */
package com.sanjaynaidu.ebayshopping.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

class ProductServiceTest {

    private final ProductService service = new ProductService(new ProductRepository());

    @Test
    void searchWithoutFiltersReturnsWholeCatalog() {
        assertThat(service.search(null, null)).hasSize(12);
        assertThat(service.search("  ", "")).hasSize(12);
    }

    @Test
    void searchFiltersByCategoryCaseInsensitively() {
        assertThat(service.search(null, "books"))
                .extracting(Product::category)
                .containsOnly("Books");
    }

    @Test
    void searchMatchesNameAndDescription() {
        assertThat(service.search("KUBERNETES", null)).extracting(Product::id).contains(12L);
        assertThat(service.search("espresso", "Home & Kitchen")).extracting(Product::id).containsExactly(9L);
        assertThat(service.search("no-such-thing", null)).isEmpty();
    }

    @Test
    void getByIdThrowsForUnknownProduct() {
        assertThatThrownBy(() -> service.getById(999)).isInstanceOf(ProductNotFoundException.class);
    }

    @Test
    void categoriesAreDistinctAndSorted() {
        assertThat(service.categories()).containsExactly("Books", "Electronics", "Fashion", "Home & Kitchen");
    }

    @Test
    void discountPercentIsRoundedDownAndZeroWithoutDiscount() {
        Product discounted = new Product(1, "a", "c", "d", new BigDecimal("75"), new BigDecimal("100"), 4, 1, "x");
        Product fullPrice = new Product(2, "a", "c", "d", new BigDecimal("100"), new BigDecimal("100"), 4, 1, "x");
        Product noListPrice = new Product(3, "a", "c", "d", new BigDecimal("100"), null, 4, 0, "x");

        assertThat(discounted.discountPercent()).isEqualTo(25);
        assertThat(fullPrice.discountPercent()).isZero();
        assertThat(noListPrice.discountPercent()).isZero();
        assertThat(noListPrice.inStock()).isFalse();
    }
}
