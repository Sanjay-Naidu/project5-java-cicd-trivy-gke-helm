# =============================================================================
# Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
# Author  : Sanjay Naidu
# File    : Dockerfile - multi-stage, distroless, non-root production image
# =============================================================================
# WHY multi-stage  : Maven, the JDK and the source code never ship to
#                    production - only the JRE and the app's layers do.
# WHY distroless   : no shell, no package manager, no curl. Far fewer OS
#                    packages means far fewer CVEs for Trivy to flag, and an
#                    attacker who gets code execution has no tools to use.
# WHY layered jar  : Spring Boot splits the jar into dependencies / loader /
#                    application layers. Dependencies rarely change, so a code
#                    change re-pushes only a few KB instead of the whole ~25MB.
# WHY nonroot tag  : distroless ':nonroot' runs as UID 65532 - matches the
#                    Helm chart's runAsNonRoot/runAsUser settings.

# ---------- Stage 1 : build ----------
FROM maven:3.9.16-eclipse-temurin-21 AS build

WORKDIR /build

# pom.xml first: the dependency download layer is cached and only re-runs
# when dependencies change, not on every code edit.
COPY app/pom.xml .
RUN mvn -B -ntp dependency:go-offline

COPY app/src ./src

# Tests already ran in the CI quality job (same commit) - skip them here so
# the image build stays fast. The image is still gated by the Trivy scan.
RUN mvn -B -ntp -DskipTests package \
    && java -Djarmode=tools -jar target/ebayshopping.jar extract --layers --destination extracted

# ---------- Stage 2 : runtime ----------
FROM gcr.io/distroless/java21-debian13:nonroot

LABEL org.opencontainers.image.title="ebayshopping" \
      org.opencontainers.image.authors="Sanjay Naidu" \
      org.opencontainers.image.description="ebayshopping Spring Boot storefront deployed to GKE via Helm and GitHub Actions" \
      org.opencontainers.image.source="https://github.com/Sanjay-Naidu/project5-java-cicd-trivy-gke-helm"

WORKDIR /app

# Least-changing layers first, so Docker/Artifact Registry reuse them.
COPY --from=build /build/extracted/dependencies/ ./
COPY --from=build /build/extracted/spring-boot-loader/ ./
COPY --from=build /build/extracted/snapshot-dependencies/ ./
COPY --from=build /build/extracted/application/ ./

USER 65532:65532

# 8080 = app traffic (Service/Ingress), 8081 = actuator (in-cluster only)
EXPOSE 8080 8081

# JVM flags for containers:
#   MaxRAMPercentage=75   heap sized from the pod's memory LIMIT, leaving
#                         25% for metaspace, threads and native memory.
#   ExitOnOutOfMemoryError  crash fast on OOM so Kubernetes restarts the pod
#                         instead of leaving a half-dead JVM serving errors.
# No HEALTHCHECK: distroless has no shell/curl, and Kubernetes probes
# (/livez, /readyz) are the source of truth in the cluster anyway.
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-XX:+ExitOnOutOfMemoryError", "-jar", "ebayshopping.jar"]
