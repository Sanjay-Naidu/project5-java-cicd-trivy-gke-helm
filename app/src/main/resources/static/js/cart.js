/*
 * =============================================================================
 * Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
 * Author  : Sanjay Naidu
 * File    : static/js/cart.js - browser-side cart + checkout
 * =============================================================================
 * WHY the cart lives in the browser: the pods stay stateless. No sticky
 * sessions on the load balancer, no Redis for sessions, and the HPA can kill
 * or add replicas at any moment without anyone losing their cart.
 *
 * Only {productId: quantity} is stored. Names and prices are always fetched
 * fresh from /api/products, and the final order is priced by the server.
 */
(function () {
    "use strict";

    var KEY = "ebayshopping.cart";
    var inr = new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 });

    function load() {
        try {
            return JSON.parse(localStorage.getItem(KEY)) || {};
        } catch (e) {
            return {};
        }
    }

    function save(cart) {
        try {
            localStorage.setItem(KEY, JSON.stringify(cart));
        } catch (e) { /* private mode / storage full - cart just won't persist */ }
        updateBadge();
    }

    function count(cart) {
        return Object.values(cart).reduce(function (a, b) { return a + b; }, 0);
    }

    function updateBadge() {
        document.querySelectorAll("[data-cart-count]").forEach(function (el) {
            el.textContent = count(load());
        });
    }

    function add(id) {
        var cart = load();
        cart[id] = Math.min((cart[id] || 0) + 1, 10);
        save(cart);
    }

    // Text is always inserted via textContent (never innerHTML with data)
    // so product names can never inject markup.
    function el(tag, text, cls) {
        var e = document.createElement(tag);
        if (text !== undefined && text !== null) { e.textContent = text; }
        if (cls) { e.className = cls; }
        return e;
    }

    function fetchProducts() {
        return fetch("/api/products").then(function (r) {
            if (!r.ok) { throw new Error("Could not load products"); }
            return r.json();
        });
    }

    // Join the stored quantities with fresh catalog data.
    function cartLines(products) {
        var cart = load();
        return products
            .filter(function (p) { return cart[p.id]; })
            .map(function (p) { return { product: p, qty: cart[p.id] }; });
    }

    function subtotal(lines) {
        return lines.reduce(function (sum, l) { return sum + Number(l.product.price) * l.qty; }, 0);
    }

    // ---------- cart page ----------
    function renderCart(view) {
        fetchProducts().then(function (products) {
            var lines = cartLines(products);
            view.replaceChildren();
            if (lines.length === 0) {
                var p = el("p", "Your cart is empty. ", "empty");
                var a = el("a", "Continue shopping");
                a.href = "/";
                p.appendChild(a);
                view.appendChild(p);
                return;
            }
            var table = el("table", null, "cart-table");
            var head = el("tr");
            ["", "Product", "Price", "Qty", "Total", ""].forEach(function (h) { head.appendChild(el("th", h)); });
            table.appendChild(head);

            lines.forEach(function (l) {
                var tr = el("tr");
                tr.appendChild(el("td", l.product.icon));
                var nameTd = el("td");
                var link = el("a", l.product.name);
                link.href = "/products/" + l.product.id;
                nameTd.appendChild(link);
                tr.appendChild(nameTd);
                tr.appendChild(el("td", inr.format(l.product.price)));

                var qtyTd = el("td");
                var input = el("input");
                input.type = "number";
                input.min = 1;
                input.max = 10;
                input.value = l.qty;
                input.addEventListener("change", function () {
                    var cart = load();
                    cart[l.product.id] = Math.max(1, Math.min(10, parseInt(input.value, 10) || 1));
                    save(cart);
                    renderCart(view);
                });
                qtyTd.appendChild(input);
                tr.appendChild(qtyTd);

                tr.appendChild(el("td", inr.format(Number(l.product.price) * l.qty)));
                var rmTd = el("td");
                var rm = el("button", "Remove", "btn-link");
                rm.addEventListener("click", function () {
                    var cart = load();
                    delete cart[l.product.id];
                    save(cart);
                    renderCart(view);
                });
                rmTd.appendChild(rm);
                tr.appendChild(rmTd);
                table.appendChild(tr);
            });
            view.appendChild(table);

            var totals = el("div", null, "totals");
            totals.appendChild(el("p", "Subtotal: " + inr.format(subtotal(lines)), "grand"));
            totals.appendChild(el("p", "Shipping is calculated at checkout.", "note"));
            var go = el("a", "Proceed to checkout", "btn btn-lg");
            go.href = "/checkout";
            totals.appendChild(go);
            view.appendChild(totals);
        }).catch(function (e) {
            view.replaceChildren(el("p", e.message, "error"));
        });
    }

    // ---------- checkout page ----------
    function renderSummary(aside, lines) {
        aside.replaceChildren(el("h2", "Order summary"));
        if (lines.length === 0) {
            aside.appendChild(el("p", "Your cart is empty.", "empty"));
            return;
        }
        lines.forEach(function (l) {
            var row = el("div", null, "summary-line");
            row.appendChild(el("span", l.product.name + " x " + l.qty));
            row.appendChild(el("span", inr.format(Number(l.product.price) * l.qty)));
            aside.appendChild(row);
        });
        var total = el("div", null, "summary-line");
        total.appendChild(el("strong", "Subtotal"));
        total.appendChild(el("strong", inr.format(subtotal(lines))));
        aside.appendChild(total);
    }

    function renderConfirmation(view, order) {
        var box = el("div", null, "success");
        box.appendChild(el("h2", "Thank you, " + order.customerName + "!"));
        box.appendChild(el("p", "Order " + order.orderId + " is confirmed."));
        order.items.forEach(function (i) {
            var row = el("div", null, "summary-line");
            row.appendChild(el("span", i.name + " x " + i.quantity));
            row.appendChild(el("span", inr.format(i.lineTotal)));
            box.appendChild(row);
        });
        [["Subtotal", order.subtotal], ["Shipping", order.shipping], ["Total", order.total]].forEach(function (t) {
            var row = el("div", null, "summary-line");
            row.appendChild(el("strong", t[0]));
            row.appendChild(el("strong", inr.format(t[1])));
            box.appendChild(row);
        });
        box.appendChild(el("p", "Processed by pod " + order.servedBy, "note"));
        var back = el("a", "Continue shopping", "btn");
        back.href = "/";
        box.appendChild(back);
        view.replaceChildren(box);
    }

    function setupCheckout(view) {
        var form = view.querySelector("[data-checkout-form]");
        var aside = view.querySelector("[data-checkout-summary]");
        var errorEl = view.querySelector("[data-checkout-error]");
        var lines = [];

        fetchProducts().then(function (products) {
            lines = cartLines(products);
            renderSummary(aside, lines);
        });

        form.addEventListener("submit", function (ev) {
            ev.preventDefault();
            errorEl.hidden = true;
            if (lines.length === 0) {
                errorEl.textContent = "Your cart is empty.";
                errorEl.hidden = false;
                return;
            }
            var data = new FormData(form);
            var body = {
                customerName: data.get("customerName"),
                email: data.get("email"),
                address: data.get("address"),
                items: lines.map(function (l) { return { productId: l.product.id, quantity: l.qty }; })
            };
            fetch("/api/orders", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(body)
            }).then(function (r) {
                return r.json().then(function (json) { return { ok: r.ok, json: json }; });
            }).then(function (res) {
                if (!res.ok) {
                    errorEl.textContent = res.json.detail || "Could not place the order.";
                    errorEl.hidden = false;
                    return;
                }
                save({});
                renderConfirmation(view, res.json);
            }).catch(function () {
                errorEl.textContent = "Network error - please try again.";
                errorEl.hidden = false;
            });
        });
    }

    document.addEventListener("DOMContentLoaded", function () {
        updateBadge();

        document.querySelectorAll("[data-add-to-cart]").forEach(function (btn) {
            btn.addEventListener("click", function () {
                add(btn.getAttribute("data-add-to-cart"));
                var original = btn.textContent;
                btn.textContent = "Added ✓";
                setTimeout(function () { btn.textContent = original; }, 1200);
            });
        });

        var cartView = document.querySelector("[data-cart-view]");
        if (cartView) { renderCart(cartView); }

        var checkoutView = document.querySelector("[data-checkout-view]");
        if (checkoutView) { setupCheckout(checkoutView); }
    });
})();
