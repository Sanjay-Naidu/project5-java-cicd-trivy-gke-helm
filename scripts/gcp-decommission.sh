#!/usr/bin/env bash
# =============================================================================
# Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
# Author  : Sanjay Naidu
# File    : scripts/gcp-decommission.sh - delete EVERYTHING gcp-setup.sh made
# =============================================================================
# ORDER MATTERS. The ingress load balancer and its NEGs are created by the
# GKE ingress controller, not by this script. If the cluster is deleted
# first, the controller is gone before it can clean them up - the LB keeps
# billing and the orphaned NEGs block the VPC from being deleted. So:
#   1. uninstall the apps -> the controller tears down the LB
#   2. wait until the LB is really gone
#   3. only then delete the cluster, network, registry and identities
#
# Usage (Cloud Shell, repo root):
#   bash scripts/gcp-decommission.sh
# =============================================================================
set -uo pipefail   # no -e: keep going if one resource is already gone

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/config.sh
source "${SCRIPT_DIR}/config.sh"
require_project

PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"

echo "This permanently deletes the ebayshopping platform in project '${PROJECT_ID}':"
echo "  cluster ${CLUSTER}, load balancer, static IP, NAT, VPC, Artifact Registry"
echo "  repo (all images), service accounts and the GitHub OIDC trust."
read -r -p "Type the project id to confirm: " CONFIRM
if [[ "${CONFIRM}" != "${PROJECT_ID}" ]]; then
  echo "Aborted - nothing was deleted."
  exit 1
fi

# -----------------------------------------------------------------------------
step "1/7 Uninstalling the app so GKE deletes the load balancer"
# -----------------------------------------------------------------------------
if gcloud container clusters describe "${CLUSTER}" --zone "${ZONE}" >/dev/null 2>&1; then
  gcloud container clusters get-credentials "${CLUSTER}" --zone "${ZONE}"
  for ns in prod dev; do
    helm uninstall ebayshopping -n "${ns}" --wait 2>/dev/null && info "helm release removed from ${ns}"
    kubectl delete namespace "${ns}" --ignore-not-found --wait=true --timeout=5m
  done

  info "Waiting for the ingress load balancer to be removed (up to 10 min)..."
  for _ in $(seq 1 60); do
    LEFT="$(gcloud compute forwarding-rules list --global \
      --filter="name~ebayshopping OR description~ebayshopping" --format='value(name)' 2>/dev/null)"
    [[ -z "${LEFT}" ]] && break
    sleep 10
  done
  [[ -n "${LEFT:-}" ]] && info "WARNING: forwarding rules still present: ${LEFT} (cleaned up below)"
else
  skip "cluster already gone"
fi

# -----------------------------------------------------------------------------
step "2/7 Deleting GKE cluster (~5 minutes)"
# -----------------------------------------------------------------------------
gcloud container clusters delete "${CLUSTER}" --zone "${ZONE}" --quiet 2>/dev/null \
  || skip "cluster ${CLUSTER} not found"

# -----------------------------------------------------------------------------
step "3/7 Removing any load balancer leftovers + static IP"
# -----------------------------------------------------------------------------
# Belt and braces: anything the ingress controller left behind. GKE names
# these k8s2-...-<namespace>-ebayshopping-...
for fr in $(gcloud compute forwarding-rules list --global --filter="name~ebayshopping" --format='value(name)'); do
  gcloud compute forwarding-rules delete "${fr}" --global --quiet
done
for tp in $(gcloud compute target-http-proxies list --filter="name~ebayshopping" --format='value(name)'); do
  gcloud compute target-http-proxies delete "${tp}" --quiet
done
for um in $(gcloud compute url-maps list --filter="name~ebayshopping" --format='value(name)'); do
  gcloud compute url-maps delete "${um}" --quiet
done
for bs in $(gcloud compute backend-services list --global --filter="name~ebayshopping" --format='value(name)'); do
  gcloud compute backend-services delete "${bs}" --global --quiet
done
for hc in $(gcloud compute health-checks list --filter="name~ebayshopping" --format='value(name)'); do
  gcloud compute health-checks delete "${hc}" --quiet
done
gcloud compute network-endpoint-groups list --filter="network~${NETWORK}" \
  --format='value(name,zone.basename())' 2>/dev/null | while read -r neg zone; do
  [[ -n "${neg}" ]] && gcloud compute network-endpoint-groups delete "${neg}" --zone "${zone}" --quiet
done
gcloud compute addresses delete "${STATIC_IP}" --global --quiet 2>/dev/null \
  || skip "static IP ${STATIC_IP} not found"

# -----------------------------------------------------------------------------
step "4/7 Deleting network: NAT, router, firewall rules, subnet, VPC"
# -----------------------------------------------------------------------------
gcloud compute routers nats delete "${NAT}" --router "${ROUTER}" --region "${REGION}" --quiet 2>/dev/null \
  || skip "NAT ${NAT} not found"
gcloud compute routers delete "${ROUTER}" --region "${REGION}" --quiet 2>/dev/null \
  || skip "router ${ROUTER} not found"
# GKE-created rules (gke-*, k8s-*) normally go with the cluster; sweep any
# stragglers so the VPC delete does not fail.
for fw in $(gcloud compute firewall-rules list --filter="network~${NETWORK}" --format='value(name)'); do
  gcloud compute firewall-rules delete "${fw}" --quiet
done
gcloud compute networks subnets delete "${SUBNET}" --region "${REGION}" --quiet 2>/dev/null \
  || skip "subnet ${SUBNET} not found"
gcloud compute networks delete "${NETWORK}" --quiet 2>/dev/null \
  || skip "VPC ${NETWORK} not found"

# -----------------------------------------------------------------------------
step "5/7 Deleting Artifact Registry repo (all images)"
# -----------------------------------------------------------------------------
gcloud artifacts repositories delete "${AR_REPO}" --location "${REGION}" --quiet 2>/dev/null \
  || skip "repo ${AR_REPO} not found"

# -----------------------------------------------------------------------------
step "6/7 Removing GitHub OIDC trust (pool is soft-deleted for 30 days)"
# -----------------------------------------------------------------------------
gcloud iam workload-identity-pools providers delete "${WIF_PROVIDER}" \
  --location global --workload-identity-pool "${WIF_POOL}" --quiet 2>/dev/null \
  || skip "provider ${WIF_PROVIDER} not found"
gcloud iam workload-identity-pools delete "${WIF_POOL}" --location global --quiet 2>/dev/null \
  || skip "pool ${WIF_POOL} not found"

# -----------------------------------------------------------------------------
step "7/7 Removing project IAM bindings and service accounts"
# -----------------------------------------------------------------------------
# Remove the project-level bindings first, otherwise they linger in the IAM
# policy as "deleted:serviceAccount:..." entries.
gcloud projects remove-iam-policy-binding "${PROJECT_ID}" \
  --member "serviceAccount:${DEPLOY_SA}" --role roles/container.developer \
  --condition None --quiet >/dev/null 2>&1 || true
gcloud projects remove-iam-policy-binding "${PROJECT_ID}" \
  --member "serviceAccount:${NODE_SA}" --role roles/container.defaultNodeServiceAccount \
  --condition None --quiet >/dev/null 2>&1 || true
gcloud iam service-accounts delete "${DEPLOY_SA}" --quiet 2>/dev/null || skip "${DEPLOY_SA} not found"
gcloud iam service-accounts delete "${NODE_SA}" --quiet 2>/dev/null || skip "${NODE_SA} not found"

# -----------------------------------------------------------------------------
step "Decommission complete - verifying nothing billable is left"
# -----------------------------------------------------------------------------
echo "Clusters:";          gcloud container clusters list --format='value(name)'
echo "VM instances:";      gcloud compute instances list --format='value(name)'
echo "Forwarding rules:";  gcloud compute forwarding-rules list --format='value(name)'
echo "Static IPs:";        gcloud compute addresses list --format='value(name)'
echo "Disks:";             gcloud compute disks list --format='value(name)'
cat <<EOF

  Empty lists above = nothing left running.
  Remember to delete the GitHub variables GCP_PROJECT_ID etc. (or leave them:
  the pipeline skips push/deploy when GCP_PROJECT_ID is empty).

  Nuclear option - removes the WHOLE project and everything in it:
    gcloud projects delete ${PROJECT_ID}
  (Project ${PROJECT_NUMBER} can be restored for 30 days after that.)

EOF
