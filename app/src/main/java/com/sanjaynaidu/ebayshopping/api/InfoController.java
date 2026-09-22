/*
 * =============================================================================
 * Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
 * Author  : Sanjay Naidu
 * File    : api/InfoController.java - build/runtime identity endpoint
 * =============================================================================
 * GET /api/info answers "what exactly is running here?" in one call: the
 * image tag (sha-<commit>), the environment and the pod that answered. The
 * prod deploy job reads this after rollout and fails if the version does not
 * match the tag it just deployed.
 */
package com.sanjaynaidu.ebayshopping.api;

import com.sanjaynaidu.ebayshopping.config.AppProperties;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class InfoController {

    private final AppProperties props;

    public InfoController(AppProperties props) {
        this.props = props;
    }

    @GetMapping("/api/info")
    public Map<String, String> info() {
        Map<String, String> info = new LinkedHashMap<>();
        info.put("app", props.name());
        info.put("version", props.version());
        info.put("environment", props.environment());
        info.put("pod", Optional.ofNullable(System.getenv("HOSTNAME")).orElse("local"));
        info.put("java", System.getProperty("java.version"));
        return info;
    }
}
