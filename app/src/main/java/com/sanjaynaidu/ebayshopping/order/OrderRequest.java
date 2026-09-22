/*
 * =============================================================================
 * Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
 * Author  : Sanjay Naidu
 * File    : order/OrderRequest.java - checkout payload (validated at the edge)
 * =============================================================================
 * Deliberately carries NO prices: the client only says what it wants and how
 * many. Prices are always looked up server-side - a browser can be edited,
 * the catalog cannot.
 */
package com.sanjaynaidu.ebayshopping.order;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.util.List;

public record OrderRequest(
        @NotBlank @Size(max = 100) String customerName,
        @NotBlank @Email @Size(max = 200) String email,
        @NotBlank @Size(max = 300) String address,
        @NotEmpty @Size(max = 20) List<@Valid Line> items) {

    public record Line(
            @Positive long productId,
            @Min(1) @Max(10) int quantity) {
    }
}
