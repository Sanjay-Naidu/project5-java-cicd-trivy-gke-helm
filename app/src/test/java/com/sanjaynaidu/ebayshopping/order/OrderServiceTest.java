/*
 * =============================================================================
 * Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
 * Author  : Sanjay Naidu
 * File    : order/OrderServiceTest.java - pricing rules (unit tests)
 * =============================================================================
 */
package com.sanjaynaidu.ebayshopping.order;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.sanjaynaidu.ebayshopping.catalog.ProductNotFoundException;
import com.sanjaynaidu.ebayshopping.catalog.ProductRepository;
import com.sanjaynaidu.ebayshopping.catalog.ProductService;
import com.sanjaynaidu.ebayshopping.config.AppProperties;
import java.math.BigDecimal;
import java.util.List;
import org.junit.jupiter.api.Test;

class OrderServiceTest {

    private final AppProperties props = new AppProperties(
            "ebayshopping", "test", "test", new BigDecimal("999"), new BigDecimal("49"));
    private final OrderService service = new OrderService(new ProductService(new ProductRepository()), props);

    private static OrderRequest request(OrderRequest.Line... lines) {
        return new OrderRequest("  Test User  ", "test@example.com", "1 Test Street", List.of(lines));
    }

    @Test
    void pricesLinesFromTheCatalogAndGivesFreeShippingAboveThreshold() {
        // product 1 = 7999
        Order order = service.place(request(new OrderRequest.Line(1, 2)));

        assertThat(order.subtotal()).isEqualByComparingTo("15998");
        assertThat(order.shipping()).isEqualByComparingTo("0");
        assertThat(order.total()).isEqualByComparingTo("15998");
        assertThat(order.customerName()).isEqualTo("Test User");
        assertThat(order.orderId()).startsWith("EBS-");
    }

    @Test
    void chargesShippingBelowThreshold() {
        // product 7 = 799
        Order order = service.place(request(new OrderRequest.Line(7, 1)));

        assertThat(order.shipping()).isEqualByComparingTo("49");
        assertThat(order.total()).isEqualByComparingTo("848");
    }

    @Test
    void shippingThresholdIsInclusive() {
        assertThat(service.shippingFor(new BigDecimal("999"))).isEqualByComparingTo("0");
        assertThat(service.shippingFor(new BigDecimal("998"))).isEqualByComparingTo("49");
    }

    @Test
    void mergesDuplicateLinesBeforeCheckingStock() {
        // product 9 has 8 in stock: 5 + 5 = 10 must be rejected even though
        // each line on its own would pass.
        assertThatThrownBy(() -> service.place(request(new OrderRequest.Line(9, 5), new OrderRequest.Line(9, 5))))
                .isInstanceOf(OutOfStockException.class);

        Order merged = service.place(request(new OrderRequest.Line(10, 1), new OrderRequest.Line(10, 2)));
        assertThat(merged.items()).hasSize(1);
        assertThat(merged.items().getFirst().quantity()).isEqualTo(3);
    }

    @Test
    void rejectsOutOfStockAndUnknownProducts() {
        assertThatThrownBy(() -> service.place(request(new OrderRequest.Line(12, 1))))
                .isInstanceOf(OutOfStockException.class)
                .hasMessageContaining("Only 0");
        assertThatThrownBy(() -> service.place(request(new OrderRequest.Line(404, 1))))
                .isInstanceOf(ProductNotFoundException.class);
    }
}
