#!/usr/bin/env bash
# =============================================================================
# Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
# Author  : Sanjay Naidu
# File    : scripts/config.sh - ONE place for every name the scripts use
# =============================================================================
# Sourced by gcp-setup.sh, gke-pause.sh and gcp-decommission.sh so that
# create, pause and delete can never disagree about what a resource is called.
# Edit GITHUB_REPO (and optionally REGION/ZONE) before the first run.

# --- GCP project: defaults to whatever `gcloud config set project` selected ---
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"

# --- Location ---
# us-central1 is one of the cheapest regions for e2 machines. asia-south1
# (Mumbai) works too - roughly 15-20% more expensive for the same VMs.
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"

# --- GitHub repository allowed to deploy (owner/name, case-sensitive) ---
GITHUB_REPO="${GITHUB_REPO:-Sanjay-Naidu/project5-java-cicd-trivy-gke-helm}"

# --- Resource names ---
CLUSTER="ebayshopping-gke"
AR_REPO="ebayshopping"
NETWORK="ebayshopping-vpc"
SUBNET="ebayshopping-subnet"
ROUTER="ebayshopping-router"
NAT="ebayshopping-nat"
STATIC_IP="ebayshopping-ip"               # must match values-prod.yaml
NODE_SA_NAME="gke-nodes"
DEPLOY_SA_NAME="github-deployer"
WIF_POOL="github-pool"
WIF_PROVIDER="github-oidc"

# --- Node pool sizing (see README "cost" section for the reasoning) ---
MACHINE_TYPE="e2-medium"                  # 2 shared vCPU, 4 GB RAM
NODE_COUNT=2
MIN_NODES=1
MAX_NODES=3                               # 3 x 2 vCPU stays under the free-trial 8 vCPU cap
DISK_TYPE="pd-standard"                   # HDD: cheapest, and avoids the trial's SSD quota
DISK_SIZE=30

# --- Derived values ---
NODE_SA="${NODE_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
DEPLOY_SA="${DEPLOY_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
AR_HOST="${REGION}-docker.pkg.dev"

# --- Tiny logging helpers ---
step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
skip() { printf '    \033[0;33m(exists) %s\033[0m\n' "$*"; }

require_project() {
  if [[ -z "${PROJECT_ID}" || "${PROJECT_ID}" == "(unset)" ]]; then
    echo "No GCP project selected. Run: gcloud config set project <PROJECT_ID>" >&2
    exit 1
  fi
}
