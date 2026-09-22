/*
 * =============================================================================
 * Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
 * Author  : Sanjay Naidu
 * File    : order/OrderService.java - server-side pricing and checkout
 * =============================================================================
 * The cart lives in the browser (localStorage), which keeps every pod
 * stateless: no sticky sessions, no session store, any replica can serve any
 * request. The trade-off is that nothing from the client is trusted - this
 * service re-prices every line from the catalog and re-checks stock.
 *
 * Orders are not persisted (no database in this project, by design). The
 * confirmation is returned in the response, which is all the UI needs.
 */
package com.sanjaynaidu.ebayshopping.order;

import com.sanjaynaidu.ebayshopping.catalog.Product;
import com.sanjaynaidu.ebayshopping.catalog.ProductService;
import com.sanjaynaidu.ebayshopping.config.AppProperties;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Service;

@Service
public class OrderService {

    private final ProductService productService;
    private final AppProperties props;

    public OrderService(ProductService productService, AppProperties props) {
        this.productService = productService;
        this.props = props;
    }

    public Order place(OrderRequest request) {
        // The same product added twice (e.g. from two tabs) is merged into one
        // line so the stock check sees the real total quantity.
        Map<Long, Integer> quantities = new LinkedHashMap<>();
        for (OrderRequest.Line line : request.items()) {
            quantities.merge(line.productId(), line.quantity(), Integer::sum);
        }

        List<Order.Item> items = quantities.entrySet().stream()
                .map(e -> priceLine(productService.getById(e.getKey()), e.getValue()))
                .toList();

        BigDecimal subtotal = items.stream()
                .map(Order.Item::lineTotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal shipping = shippingFor(subtotal);

        return new Order(
                "EBS-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase(),
                Instant.now(),
                request.customerName().trim(),
                items,
                subtotal,
                shipping,
                subtotal.add(shipping),
                podName());
    }

    /** Free shipping at or above the threshold, flat fee below it. */
    BigDecimal shippingFor(BigDecimal subtotal) {
        return subtotal.compareTo(props.freeShippingThreshold()) >= 0 ? BigDecimal.ZERO : props.shippingFee();
    }

    private static Order.Item priceLine(Product product, int quantity) {
        if (quantity > product.stock()) {
            throw new OutOfStockException(product.name(), quantity, product.stock());
        }
        return new Order.Item(
                product.id(),
                product.name(),
                product.price(),
                quantity,
                product.price().multiply(BigDecimal.valueOf(quantity)));
    }

    /** Kubernetes sets HOSTNAME to the pod name - shows which replica served the request. */
    static String podName() {
        return Optional.ofNullable(System.getenv("HOSTNAME")).orElse("local");
    }
}
