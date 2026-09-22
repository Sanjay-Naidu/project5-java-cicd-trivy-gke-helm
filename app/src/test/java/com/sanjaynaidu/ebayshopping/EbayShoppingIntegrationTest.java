/*
 * =============================================================================
 * Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
 * Author  : Sanjay Naidu
 * File    : EbayShoppingIntegrationTest.java - full app over real HTTP
 * =============================================================================
 * Boots the real application on random ports (app + management) and talks to
 * it with the JDK HttpClient - exactly how Kubernetes, the load balancer and
 * a browser will. This also proves the security-relevant port split:
 * /actuator/prometheus is served on the management port and NOT on the
 * public one.
 */
package com.sanjaynaidu.ebayshopping;

import static org.assertj.core.api.Assertions.assertThat;

import com.jayway.jsonpath.JsonPath;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.env.Environment;

@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {"management.server.port=0", "app.version=sha-test123", "app.environment=test"})
class EbayShoppingIntegrationTest {

    private final HttpClient http = HttpClient.newHttpClient();

    @Autowired
    private Environment env;

    private String app(String path) {
        return "http://localhost:" + env.getProperty("local.server.port") + path;
    }

    private String mgmt(String path) {
        return "http://localhost:" + env.getProperty("local.management.port") + path;
    }

    private HttpResponse<String> get(String url) throws IOException, InterruptedException {
        return http.send(HttpRequest.newBuilder(URI.create(url)).GET().build(), HttpResponse.BodyHandlers.ofString());
    }

    private HttpResponse<String> postJson(String url, String json) throws IOException, InterruptedException {
        return http.send(HttpRequest.newBuilder(URI.create(url))
                        .header("Content-Type", "application/json")
                        .POST(HttpRequest.BodyPublishers.ofString(json))
                        .build(),
                HttpResponse.BodyHandlers.ofString());
    }

    // ---------- storefront pages ----------

    @Test
    void homePageListsProductsAndShowsBuildInfo() throws Exception {
        HttpResponse<String> res = get(app("/"));
        assertThat(res.statusCode()).isEqualTo(200);
        assertThat(res.body()).contains("ebay", "Wireless Noise-Cancelling Headphones", "sha-test123");
    }

    @Test
    void homePageSearchFilters() throws Exception {
        HttpResponse<String> res = get(app("/?q=espresso"));
        assertThat(res.statusCode()).isEqualTo(200);
        assertThat(res.body()).contains("Espresso Coffee Maker").doesNotContain("Leather Wallet");
    }

    @Test
    void productCartAndCheckoutPagesRender() throws Exception {
        assertThat(get(app("/products/3")).body()).contains("Ultrabook Laptop");
        assertThat(get(app("/cart")).statusCode()).isEqualTo(200);
        assertThat(get(app("/checkout")).statusCode()).isEqualTo(200);
    }

    @Test
    void unknownProductPageIs404() throws Exception {
        assertThat(get(app("/products/9999")).statusCode()).isEqualTo(404);
    }

    // ---------- REST API ----------

    @Test
    void productApiListsAndFilters() throws Exception {
        HttpResponse<String> all = get(app("/api/products"));
        assertThat(all.statusCode()).isEqualTo(200);
        assertThat(JsonPath.<List<Object>>read(all.body(), "$")).hasSize(12);

        HttpResponse<String> books = get(app("/api/products?category=Books"));
        assertThat(JsonPath.<List<String>>read(books.body(), "$[*].category")).containsOnly("Books");

        assertThat(JsonPath.<List<String>>read(get(app("/api/categories")).body(), "$")).contains("Electronics");
    }

    @Test
    void unknownProductApiReturnsProblemDetail() throws Exception {
        HttpResponse<String> res = get(app("/api/products/9999"));
        assertThat(res.statusCode()).isEqualTo(404);
        assertThat(JsonPath.<String>read(res.body(), "$.title")).isEqualTo("Product not found");
    }

    @Test
    void placeOrderIsPricedServerSide() throws Exception {
        HttpResponse<String> res = postJson(app("/api/orders"), """
                {"customerName":"Sanjay","email":"sanjay@example.com","address":"Hyderabad",
                 "items":[{"productId":1,"quantity":2},{"productId":7,"quantity":1}]}
                """);
        assertThat(res.statusCode()).isEqualTo(201);
        // 7999*2 + 799 = 16797, above the 999 threshold -> free shipping
        assertThat(JsonPath.<Number>read(res.body(), "$.total").intValue()).isEqualTo(16797);
        assertThat(JsonPath.<Number>read(res.body(), "$.shipping").intValue()).isZero();
    }

    @Test
    void invalidOrderIs400() throws Exception {
        HttpResponse<String> res = postJson(app("/api/orders"), """
                {"customerName":"","email":"not-an-email","address":"x","items":[]}
                """);
        assertThat(res.statusCode()).isEqualTo(400);
        assertThat(JsonPath.<String>read(res.body(), "$.detail")).contains("email", "items");
    }

    @Test
    void outOfStockOrderIs409() throws Exception {
        HttpResponse<String> res = postJson(app("/api/orders"), """
                {"customerName":"A","email":"a@example.com","address":"x","items":[{"productId":12,"quantity":1}]}
                """);
        assertThat(res.statusCode()).isEqualTo(409);
    }

    @Test
    void infoEndpointReportsVersionAndEnvironment() throws Exception {
        HttpResponse<String> res = get(app("/api/info"));
        assertThat(JsonPath.<String>read(res.body(), "$.version")).isEqualTo("sha-test123");
        assertThat(JsonPath.<String>read(res.body(), "$.environment")).isEqualTo("test");
    }

    // ---------- operability ----------

    @Test
    void probesAreServedOnTheMainPort() throws Exception {
        assertThat(get(app("/livez")).statusCode()).isEqualTo(200);
        assertThat(get(app("/readyz")).statusCode()).isEqualTo(200);
    }

    @Test
    void metricsAreOnlyOnTheManagementPort() throws Exception {
        HttpResponse<String> metrics = get(mgmt("/actuator/prometheus"));
        assertThat(metrics.statusCode()).isEqualTo(200);
        assertThat(metrics.body()).contains("jvm_memory_used_bytes");

        assertThat(get(app("/actuator/prometheus")).statusCode()).isEqualTo(404);
    }
}
