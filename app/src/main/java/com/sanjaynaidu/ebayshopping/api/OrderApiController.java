/*
 * =============================================================================
 * Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
 * Author  : Sanjay Naidu
 * File    : api/OrderApiController.java - checkout endpoint
 * =============================================================================
 */
package com.sanjaynaidu.ebayshopping.api;

import com.sanjaynaidu.ebayshopping.order.Order;
import com.sanjaynaidu.ebayshopping.order.OrderRequest;
import com.sanjaynaidu.ebayshopping.order.OrderService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class OrderApiController {

    private final OrderService orderService;

    public OrderApiController(OrderService orderService) {
        this.orderService = orderService;
    }

    @PostMapping("/orders")
    @ResponseStatus(HttpStatus.CREATED)
    public Order placeOrder(@Valid @RequestBody OrderRequest request) {
        return orderService.place(request);
    }
}
