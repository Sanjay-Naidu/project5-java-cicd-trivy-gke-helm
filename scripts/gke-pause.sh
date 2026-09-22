#!/usr/bin/env bash
# =============================================================================
# Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
# Author  : Sanjay Naidu
# File    : scripts/gke-pause.sh - scale nodes to zero between demos
# =============================================================================
# GKE has no "stop cluster" button like AKS. The equivalent is scaling the
# node pool to 0: VM cost stops, the control plane stays (its fee is covered
# by GKE's free tier for one zonal cluster), and every Deployment/Service/
# Ingress definition is kept, so `resume` brings the shop back as it was.
#
# Still billed while paused: the ingress load balancer (~$0.60/day), Cloud
# NAT and the static IP. For long breaks, decommission instead.
#
# Usage:  bash scripts/gke-pause.sh pause
#         bash scripts/gke-pause.sh resume
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/config.sh
source "${SCRIPT_DIR}/config.sh"
require_project

case "${1:-}" in
  pause)
    # The autoscaler would immediately add nodes back for the pending pods,
    # so it has to be switched off first.
    step "Disabling autoscaling and scaling ${CLUSTER} to 0 nodes"
    gcloud container clusters update "${CLUSTER}" --zone "${ZONE}" \
      --node-pool default-pool --no-enable-autoscaling --quiet
    gcloud container clusters resize "${CLUSTER}" --zone "${ZONE}" \
      --node-pool default-pool --num-nodes 0 --quiet
    info "Paused. Run 'bash scripts/gke-pause.sh resume' before the next demo."
    ;;
  resume)
    step "Scaling ${CLUSTER} back to ${NODE_COUNT} nodes and re-enabling autoscaling"
    gcloud container clusters resize "${CLUSTER}" --zone "${ZONE}" \
      --node-pool default-pool --num-nodes "${NODE_COUNT}" --quiet
    gcloud container clusters update "${CLUSTER}" --zone "${ZONE}" \
      --node-pool default-pool --enable-autoscaling \
      --min-nodes "${MIN_NODES}" --max-nodes "${MAX_NODES}" --quiet
    info "Resumed. Pods take ~2-3 minutes to become ready again."
    ;;
  *)
    echo "Usage: $0 pause|resume" >&2
    exit 1
    ;;
esac
