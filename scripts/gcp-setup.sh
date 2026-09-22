#!/usr/bin/env bash
# =============================================================================
# Project : Project 5 - Java (Spring Boot) App CI/CD on Google GKE
# Author  : Sanjay Naidu
# File    : scripts/gcp-setup.sh - one-time platform bootstrap (Cloud Shell)
# =============================================================================
# Creates everything the pipeline needs, in dependency order:
#   1. APIs            5. GKE cluster (private nodes, Workload Identity)
#   2. VPC + Cloud NAT 6. Global static IP for the ingress
#   3. Artifact Reg.   7. Deployer service account (least privilege)
#   4. Node SA         8. Workload Identity Federation for GitHub (OIDC)
#
# Idempotent: every step checks whether the resource already exists, so if
# something fails halfway (quota, typo, network) you fix it and simply run
# the script again.
#
# Usage (in Google Cloud Shell, from the repo root):
#   gcloud config set project <PROJECT_ID>
#   bash scripts/gcp-setup.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/config.sh
source "${SCRIPT_DIR}/config.sh"
require_project

PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
info "Project: ${PROJECT_ID} (${PROJECT_NUMBER})  Region: ${REGION}  Zone: ${ZONE}"
info "GitHub repo allowed to deploy: ${GITHUB_REPO}"

# -----------------------------------------------------------------------------
step "1/8 Enabling APIs (first run takes 1-2 minutes)"
# -----------------------------------------------------------------------------
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  cloudresourcemanager.googleapis.com

# -----------------------------------------------------------------------------
step "2/8 Network: custom VPC, subnet with pod/service ranges, Cloud NAT"
# -----------------------------------------------------------------------------
# WHY a custom VPC instead of 'default': explicit IP plan, nothing else lives
# in it, and decommissioning is a clean delete of exactly what we made.
if gcloud compute networks describe "${NETWORK}" >/dev/null 2>&1; then
  skip "VPC ${NETWORK}"
else
  gcloud compute networks create "${NETWORK}" --subnet-mode=custom
fi

# Secondary ranges = VPC-native cluster: pods get real VPC IPs, which is
# what lets the Google LB send traffic straight to pods (NEGs).
# Private Google Access = private nodes can still pull from Artifact Registry.
if gcloud compute networks subnets describe "${SUBNET}" --region "${REGION}" >/dev/null 2>&1; then
  skip "Subnet ${SUBNET}"
else
  gcloud compute networks subnets create "${SUBNET}" \
    --network "${NETWORK}" \
    --region "${REGION}" \
    --range 10.10.0.0/20 \
    --secondary-range pods=10.20.0.0/16,services=10.30.0.0/20 \
    --enable-private-ip-google-access
fi

# Nodes have NO public IPs (private nodes). Cloud NAT gives them outbound
# internet (Docker Hub for the helm test image, OS updates) without any
# inbound exposure.
if gcloud compute routers describe "${ROUTER}" --region "${REGION}" >/dev/null 2>&1; then
  skip "Cloud Router ${ROUTER}"
else
  gcloud compute routers create "${ROUTER}" --network "${NETWORK}" --region "${REGION}"
fi

if gcloud compute routers nats describe "${NAT}" --router "${ROUTER}" --region "${REGION}" >/dev/null 2>&1; then
  skip "Cloud NAT ${NAT}"
else
  gcloud compute routers nats create "${NAT}" \
    --router "${ROUTER}" \
    --region "${REGION}" \
    --auto-allocate-nat-external-ips \
    --nat-all-subnet-ip-ranges
fi

# -----------------------------------------------------------------------------
step "3/8 Artifact Registry: Docker repo with immutable tags + cleanup policy"
# -----------------------------------------------------------------------------
if gcloud artifacts repositories describe "${AR_REPO}" --location "${REGION}" >/dev/null 2>&1; then
  skip "Artifact Registry repo ${AR_REPO}"
else
  # --immutable-tags: once sha-abc1234 is pushed it can never be overwritten,
  # so a tag always means exactly one image.
  gcloud artifacts repositories create "${AR_REPO}" \
    --repository-format docker \
    --location "${REGION}" \
    --description "ebayshopping container images" \
    --immutable-tags
fi

# Cleanup policy: keep the 10 newest images, delete anything older than
# 30 days beyond that. Keeps storage inside the 0.5 GB free tier.
POLICY_FILE="$(mktemp)"
cat > "${POLICY_FILE}" <<'EOF'
[
  {
    "name": "keep-10-most-recent",
    "action": { "type": "Keep" },
    "mostRecentVersions": { "keepCount": 10 }
  },
  {
    "name": "delete-older-than-30d",
    "action": { "type": "Delete" },
    "condition": { "olderThan": "30d" }
  }
]
EOF
gcloud artifacts repositories set-cleanup-policies "${AR_REPO}" \
  --location "${REGION}" --policy "${POLICY_FILE}" --no-dry-run --quiet >/dev/null
rm -f "${POLICY_FILE}"
info "cleanup policy applied"

# -----------------------------------------------------------------------------
step "4/8 Node service account (least privilege, instead of the Editor-level default)"
# -----------------------------------------------------------------------------
# By default GKE nodes run as the Compute Engine default SA, which has the
# broad Editor role. A dedicated SA with only node duties (logs, metrics)
# plus read access to OUR registry limits what a compromised node can do.
if gcloud iam service-accounts describe "${NODE_SA}" >/dev/null 2>&1; then
  skip "Service account ${NODE_SA}"
else
  gcloud iam service-accounts create "${NODE_SA_NAME}" --display-name "GKE nodes (ebayshopping)"
  sleep 10 # new service accounts take a few seconds to become usable in IAM
fi

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member "serviceAccount:${NODE_SA}" \
  --role roles/container.defaultNodeServiceAccount \
  --condition None --quiet >/dev/null
gcloud artifacts repositories add-iam-policy-binding "${AR_REPO}" \
  --location "${REGION}" \
  --member "serviceAccount:${NODE_SA}" \
  --role roles/artifactregistry.reader --quiet >/dev/null
info "roles: container.defaultNodeServiceAccount (project), artifactregistry.reader (repo)"

# -----------------------------------------------------------------------------
step "5/8 GKE cluster (takes ~6-10 minutes)"
# -----------------------------------------------------------------------------
if gcloud container clusters describe "${CLUSTER}" --zone "${ZONE}" >/dev/null 2>&1; then
  skip "GKE cluster ${CLUSTER}"
else
  # Flag-by-flag reasoning is in README.md ("Infrastructure" table).
  gcloud container clusters create "${CLUSTER}" \
    --zone "${ZONE}" \
    --release-channel regular \
    --network "${NETWORK}" \
    --subnetwork "${SUBNET}" \
    --enable-ip-alias \
    --cluster-secondary-range-name pods \
    --services-secondary-range-name services \
    --enable-private-nodes \
    --enable-dataplane-v2 \
    --workload-pool "${PROJECT_ID}.svc.id.goog" \
    --service-account "${NODE_SA}" \
    --machine-type "${MACHINE_TYPE}" \
    --disk-type "${DISK_TYPE}" \
    --disk-size "${DISK_SIZE}" \
    --num-nodes "${NODE_COUNT}" \
    --enable-autoscaling --min-nodes "${MIN_NODES}" --max-nodes "${MAX_NODES}" \
    --autoscaling-profile optimize-utilization \
    --enable-autorepair \
    --enable-autoupgrade \
    --enable-shielded-nodes \
    --shielded-secure-boot \
    --shielded-integrity-monitoring \
    --logging SYSTEM \
    --monitoring SYSTEM
fi

# -----------------------------------------------------------------------------
step "6/8 Global static IP for the ingress load balancer"
# -----------------------------------------------------------------------------
if gcloud compute addresses describe "${STATIC_IP}" --global >/dev/null 2>&1; then
  skip "Static IP ${STATIC_IP}"
else
  gcloud compute addresses create "${STATIC_IP}" --global --ip-version IPV4
fi
PUBLIC_IP="$(gcloud compute addresses describe "${STATIC_IP}" --global --format='value(address)')"
info "Public IP reserved: ${PUBLIC_IP}"

# -----------------------------------------------------------------------------
step "7/8 Deployer service account for GitHub Actions"
# -----------------------------------------------------------------------------
# Only two permissions: push images to THIS repo, deploy into the cluster.
# It cannot create VMs, change IAM, delete the cluster or read billing.
if gcloud iam service-accounts describe "${DEPLOY_SA}" >/dev/null 2>&1; then
  skip "Service account ${DEPLOY_SA}"
else
  gcloud iam service-accounts create "${DEPLOY_SA_NAME}" --display-name "GitHub Actions deployer (ebayshopping)"
  sleep 10
fi

gcloud artifacts repositories add-iam-policy-binding "${AR_REPO}" \
  --location "${REGION}" \
  --member "serviceAccount:${DEPLOY_SA}" \
  --role roles/artifactregistry.writer --quiet >/dev/null
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member "serviceAccount:${DEPLOY_SA}" \
  --role roles/container.developer \
  --condition None --quiet >/dev/null
info "roles: artifactregistry.writer (repo), container.developer (project)"

# -----------------------------------------------------------------------------
step "8/8 Workload Identity Federation: GitHub OIDC -> deployer SA (no keys)"
# -----------------------------------------------------------------------------
# How it works (full explanation in docs/GITHUB-OIDC-TO-GCP.md):
#   GitHub signs a short-lived JWT for each workflow run  ->  Google STS
#   verifies it against this provider  ->  the attribute condition checks the
#   token came from OUR repo  ->  STS swaps it for a 1-hour access token of
#   the deployer SA. No JSON key is ever created or stored.

POOL_STATE="$(gcloud iam workload-identity-pools describe "${WIF_POOL}" --location global --format='value(state)' 2>/dev/null || true)"
if [[ "${POOL_STATE}" == "DELETED" ]]; then
  # Pools are soft-deleted for 30 days after a decommission - bring it back.
  gcloud iam workload-identity-pools undelete "${WIF_POOL}" --location global
elif [[ -n "${POOL_STATE}" ]]; then
  skip "Workload identity pool ${WIF_POOL}"
else
  gcloud iam workload-identity-pools create "${WIF_POOL}" \
    --location global \
    --display-name "GitHub Actions"
fi

# The owner's numeric id never changes, even if the account is renamed - so
# a new account that later takes the old name cannot inherit this trust.
GITHUB_OWNER="${GITHUB_REPO%%/*}"
GITHUB_OWNER_ID="$(curl -fsS "https://api.github.com/users/${GITHUB_OWNER}" | jq -r '.id')"
info "GitHub owner ${GITHUB_OWNER} has id ${GITHUB_OWNER_ID}"

ATTRIBUTE_CONDITION="assertion.repository == '${GITHUB_REPO}' && assertion.repository_owner_id == '${GITHUB_OWNER_ID}'"
ATTRIBUTE_MAPPING="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner_id=assertion.repository_owner_id,attribute.ref=assertion.ref"

PROVIDER_STATE="$(gcloud iam workload-identity-pools providers describe "${WIF_PROVIDER}" \
  --location global --workload-identity-pool "${WIF_POOL}" --format='value(state)' 2>/dev/null || true)"
if [[ "${PROVIDER_STATE}" == "DELETED" ]]; then
  gcloud iam workload-identity-pools providers undelete "${WIF_PROVIDER}" \
    --location global --workload-identity-pool "${WIF_POOL}"
  PROVIDER_STATE="ACTIVE"
fi
if [[ -n "${PROVIDER_STATE}" ]]; then
  # Re-apply the condition in case GITHUB_REPO was changed in config.sh.
  gcloud iam workload-identity-pools providers update-oidc "${WIF_PROVIDER}" \
    --location global --workload-identity-pool "${WIF_POOL}" \
    --attribute-mapping "${ATTRIBUTE_MAPPING}" \
    --attribute-condition "${ATTRIBUTE_CONDITION}" >/dev/null
  skip "OIDC provider ${WIF_PROVIDER} (condition refreshed)"
else
  gcloud iam workload-identity-pools providers create-oidc "${WIF_PROVIDER}" \
    --location global \
    --workload-identity-pool "${WIF_POOL}" \
    --display-name "GitHub OIDC" \
    --issuer-uri "https://token.actions.githubusercontent.com" \
    --attribute-mapping "${ATTRIBUTE_MAPPING}" \
    --attribute-condition "${ATTRIBUTE_CONDITION}"
fi

# Only identities from our repository may impersonate the deployer SA.
gcloud iam service-accounts add-iam-policy-binding "${DEPLOY_SA}" \
  --role roles/iam.workloadIdentityUser \
  --member "principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL}/attribute.repository/${GITHUB_REPO}" \
  --quiet >/dev/null
info "workloadIdentityUser granted to principalSet .../attribute.repository/${GITHUB_REPO}"

WIF_PROVIDER_NAME="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL}/providers/${WIF_PROVIDER}"

# -----------------------------------------------------------------------------
step "Done. Add these as GitHub repository VARIABLES"
# -----------------------------------------------------------------------------
# (Settings -> Secrets and variables -> Actions -> Variables tab)
cat <<EOF

    GCP_PROJECT_ID      = ${PROJECT_ID}
    GCP_REGION          = ${REGION}
    GAR_REPOSITORY      = ${AR_REPO}
    GKE_CLUSTER         = ${CLUSTER}
    GKE_LOCATION        = ${ZONE}
    GCP_WIF_PROVIDER    = ${WIF_PROVIDER_NAME}
    GCP_DEPLOY_SA       = ${DEPLOY_SA}

  None of these are secrets - with OIDC there is no password or key to leak.
  After the first prod deploy the shop will be at:  http://${PUBLIC_IP}/

EOF
