/*
 * =============================================================================
 * Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
 * Author  : Sanjay Naidu
 * File    : web/ShopController.java - server-rendered storefront pages
 * =============================================================================
 * Thymeleaf pages for browsing. Cart and checkout pages are rendered here
 * too, but their contents come from the browser cart (static/js/cart.js) and
 * the order is placed through POST /api/orders.
 */
package com.sanjaynaidu.ebayshopping.web;

import com.sanjaynaidu.ebayshopping.catalog.ProductService;
import com.sanjaynaidu.ebayshopping.config.AppProperties;
import java.util.Optional;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;

@Controller
public class ShopController {

    private final ProductService productService;
    private final AppProperties props;

    public ShopController(ProductService productService, AppProperties props) {
        this.productService = productService;
        this.props = props;
    }

    /** Available on every page: header categories + footer build info. */
    @ModelAttribute
    public void common(Model model) {
        model.addAttribute("categories", productService.categories());
        model.addAttribute("app", props);
        model.addAttribute("pod", Optional.ofNullable(System.getenv("HOSTNAME")).orElse("local"));
    }

    @GetMapping("/")
    public String home(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String category,
            Model model) {
        model.addAttribute("products", productService.search(q, category));
        model.addAttribute("q", q == null ? "" : q);
        model.addAttribute("selectedCategory", category == null ? "" : category);
        return "index";
    }

    @GetMapping("/products/{id}")
    public String product(@PathVariable long id, Model model) {
        var product = productService.getById(id);
        model.addAttribute("product", product);
        var related = productService.search(null, product.category()).stream()
                .filter(p -> p.id() != id)
                .limit(3)
                .toList();
        model.addAttribute("related", related);
        return "product";
    }

    @GetMapping("/cart")
    public String cart() {
        return "cart";
    }

    @GetMapping("/checkout")
    public String checkout() {
        return "checkout";
    }
}
