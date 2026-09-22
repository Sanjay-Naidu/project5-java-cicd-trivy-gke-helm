# Setup Guide — Project 5: Java CI/CD on GKE

**Author: Sanjay Naidu**

This guide goes from an empty Google Cloud free-trial account to a public URL serving the shop, and then back to zero. Nothing is installed locally: builds run on GitHub-hosted runners, and every GCP command runs in **Cloud Shell**, the browser terminal that already has `gcloud`, `kubectl`, `helm`, `git` and `jq`. Budget about 60 minutes, most of it waiting for the cluster.

The repo name used everywhere: **`project5-java-cicd-trivy-gke-helm`**

---

## Phase 0 — What you need

- A Google Cloud **free-trial** account ($300 credit, 90 days). While it stays a trial account (you never click "Activate full account" / "Upgrade"), Google **cannot charge your card**. Resources stop when the credit or the 90 days run out.
- A GitHub account.
- `git` on your laptop, only to push the code.

---

## Phase 1 — Create a dedicated GCP project

A separate project keeps this work isolated. The nuclear cleanup option is then simply "delete the project".

1. Open [console.cloud.google.com](https://console.cloud.google.com).
2. Top bar → project picker → **New project**.
   - Name: `ebayshopping-demo`
   - Note the **Project ID** Google generates (e.g. `ebayshopping-demo-471203`). You'll use the ID, not the name.
3. **Billing** → make sure the project is linked to the *free trial* billing account (new projects on a trial account normally are).
4. Open **Cloud Shell**: the `>_` icon at the top right. A terminal opens at the bottom of the page.

```bash
gcloud config set project <PROJECT_ID>
gcloud config list                 # confirm account + project
gcloud billing projects describe <PROJECT_ID> --format='value(billingEnabled)'   # must print True
```

### Recommended: a budget alert

Console → **Billing → Budgets & alerts → Create budget**: amount `100` USD, thresholds 50% / 90% / 100%, email alerts to billing admins. On a trial it can't cost you money, but the alert tells you when the credit is burning faster than planned.

---

## Phase 2 — Put the code on GitHub

On github.com create a **public** repository named `project5-java-cicd-trivy-gke-helm`, with no README, license or .gitignore (the project already has them). Public means free unlimited Actions minutes, free Security tab / SARIF uploads, and environment protection rules on the Free plan.

From the project folder on your laptop (PowerShell):

```powershell
cd "<path>\Project-5-Java_app_CICD+trivy+GKE"
git init -b main
git config user.name  "Sanjay Naidu"
git config user.email "<your GitHub email>"
git add .
git commit -m "Project 5: Java app CI/CD on GKE - initial commit"
git remote add origin https://github.com/Sanjay-Naidu/project5-java-cicd-trivy-gke-helm.git
git push -u origin main
```

This first push triggers **Build and Deploy**. With no GCP variables set yet, it builds, tests and Trivy-scans the image and then **skips** push/deploy. That's expected, and a useful first check that the Java build is green.

---

## Phase 3 — Build the platform (Cloud Shell)

```bash
git clone https://github.com/Sanjay-Naidu/project5-java-cicd-trivy-gke-helm.git
cd project5-java-cicd-trivy-gke-helm

# Optional: review / change region, zone or names first
cat scripts/config.sh

bash scripts/gcp-setup.sh
```

What it does, in order (every command is commented in the script, so read along):

| Step | Creates | Time |
|---|---|---|
| 1 | Enables Compute, GKE, Artifact Registry, IAM, STS APIs | 1–2 min |
| 2 | VPC `ebayshopping-vpc`, subnet with pod/service ranges, Cloud Router + NAT | 1 min |
| 3 | Artifact Registry repo `ebayshopping` (immutable tags, keep-last-10 cleanup) | seconds |
| 4 | Node service account `gke-nodes` (least privilege) | seconds |
| 5 | GKE cluster `ebayshopping-gke`: 2 × e2-medium, private nodes, autoscaling 1–3 | **6–10 min** |
| 6 | Global static IP `ebayshopping-ip` | seconds |
| 7 | Deployer service account `github-deployer` | seconds |
| 8 | Workload identity pool + GitHub OIDC provider + impersonation binding | seconds |

If anything fails (quota, typo, a network blip), fix it and **run the script again**. Finished steps print `(exists)` and are skipped.

At the end it prints a block like this. **Copy it.**

```
GCP_PROJECT_ID      = ebayshopping-demo-471203
GCP_REGION          = us-central1
GAR_REPOSITORY      = ebayshopping
GKE_CLUSTER         = ebayshopping-gke
GKE_LOCATION        = us-central1-a
GCP_WIF_PROVIDER    = projects/123456789012/locations/global/workloadIdentityPools/github-pool/providers/github-oidc
GCP_DEPLOY_SA       = github-deployer@ebayshopping-demo-471203.iam.gserviceaccount.com
```

Quick look at what you built:

```bash
# --dns-endpoint: the IP endpoint is restricted to authorized networks
gcloud container clusters get-credentials ebayshopping-gke --zone us-central1-a --dns-endpoint
kubectl get nodes -o wide          # 2 nodes, INTERNAL-IP only (private nodes)
```

---

## Phase 4 — Connect GitHub to GCP

### 4.1 Variables

In the repo, go to **Settings → Secrets and variables → Actions → Variables tab → New repository variable**, and add the seven values from Phase 3.

They go under **Variables**, not Secrets, because none of them is a secret. With OIDC there is no password or key to protect. The provider name and SA email are useless without a token that GitHub signs for *this* repository. (How that works: [GITHUB-OIDC-TO-GCP.md](GITHUB-OIDC-TO-GCP.md).)

### 4.2 Environments

**Settings → Environments**:

| Environment | Protection |
|---|---|
| `dev` | none, deploys automatically |
| `prod` | **Required reviewers: yourself**. Every prod deploy pauses for your approval. Also untick "Prevent self-review" if it's shown. |

### 4.3 Branch protection (optional, recommended)

**Settings → Branches → Add rule for `main`**: require a pull request + require the *PR Validation* status checks (they appear in the list after the first PR run). This makes the PR pipeline an actual gate.

---

## Phase 5 — First deployment

**Actions → Build and Deploy → Run workflow → main** (or push any commit).

Watch the run: `Code quality` → `Build, scan, push` → `Deploy to DEV` → **Waiting for approval** → click **Review deployments → prod → Approve** → `Deploy to PROD`.

The first prod deploy takes longer because Google is building the global load balancer (~5–10 minutes). The last step keeps retrying and succeeds once the public URL serves the new version. The job summary and the `prod` environment link then show the URL:

```
http://<STATIC_IP>/
```

Later deploys reuse the load balancer and finish in a couple of minutes.

---

## Phase 6 — Verify and demo

```bash
kubectl get pods -n dev
kubectl get pods,svc,ingress,hpa,pdb -n prod

# Which build is live? (version = sha-<commit> of the last merge)
curl http://<STATIC_IP>/api/info

# Dev has no ingress by design: port-forward, then use Cloud Shell's
# "Web preview -> Preview on port 8080" button
kubectl -n dev port-forward svc/ebayshopping 8080:80

# Actuator is NOT public (this should be 404):
curl -s -o /dev/null -w '%{http_code}\n' http://<STATIC_IP>/actuator/prometheus
# ...but it is reachable inside the cluster on 8081:
kubectl -n prod port-forward deploy/ebayshopping 8081:8081   # then curl localhost:8081/actuator/prometheus
```

A 5-minute interview demo:

1. Open the shop, add items to the cart, check out. The confirmation shows *which pod* processed the order.
2. Change something visible (e.g. the hero text in `index.html`), open a PR, and show PR Validation: tests, Trivy, Helm lint.
3. Merge, then show the pipeline graph, the Trivy step, the SBOM artifact, and the approval gate.
4. Refresh the site: the footer version changes to the new `sha-…`, with no downtime while the pods roll.
5. `kubectl get hpa,pdb -n prod`, and explain the zero-downtime budget (preStop + graceful shutdown + LB draining).

---

## Phase 7 — Cost control (do this religiously)

```bash
# Between demos: nodes to 0 (the LB/NAT/IP keep billing, ~$1/day)
bash scripts/gke-pause.sh pause
bash scripts/gke-pause.sh resume          # ~3 min until pods are Ready

# Check what the credit has been spent on:
# Console -> Billing -> Reports (group by Service)
```

---

## Phase 8 — Decommission (when you're done)

```bash
cd ~/project5-java-cicd-trivy-gke-helm
bash scripts/gcp-decommission.sh          # asks you to type the project id
```

The order is: apps (so GKE deletes the load balancer) → wait → cluster → LB leftovers + static IP → NAT/router/firewall/subnet/VPC → Artifact Registry → OIDC pool/provider → service accounts. At the end it lists clusters, VMs, forwarding rules, IPs and disks. **All empty = nothing is billing.**

Then, in GitHub, delete the `GCP_PROJECT_ID` variable (or all seven). The pipeline notices and goes back to build + scan only, and stays green.

Nuclear option, which removes everything in the project at once:

```bash
gcloud projects delete <PROJECT_ID>
```

To bring it all back later: run `gcp-setup.sh` again, re-add the variables, and re-run the workflow. The OIDC pool is soft-deleted for 30 days, and the script automatically *undeletes* it during that window.

---

## Optional — SonarCloud

1. [sonarcloud.io](https://sonarcloud.io) → **Log in with GitHub** → import your organization (free for public repos).
2. **Analyze new project** → select this repo → Administration → Analysis Method → turn **OFF Automatic Analysis** (it conflicts with CI analysis).
3. My Account → Security → **Generate token** → GitHub **secret** `SONAR_TOKEN`.
4. GitHub **variables**: `SONAR_ENABLED=true`, `SONAR_ORGANIZATION=<org key>`, `SONAR_PROJECT_KEY=<project key>`.

The next run includes the analysis and fails if the quality gate fails.

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `google-github-actions/auth`: *"unable to exchange token … permission denied"* / `attribute condition` rejected | The token's `repository` doesn't match `GITHUB_REPO` in `scripts/config.sh` (it's case-sensitive). Fix it and re-run `gcp-setup.sh`, which refreshes the condition. |
| auth: *"Permission 'iam.serviceAccounts.getAccessToken' denied"* | The `workloadIdentityUser` binding is missing or still propagating. Wait 2–5 minutes after setup, or re-run step 8. |
| Cluster create: *"Quota 'CPUS' exceeded"* or *"SSD_TOTAL_GB"* | Free-trial limits. Keep `MAX_NODES=3` and `pd-standard`, or switch `REGION`/`ZONE` in `config.sh` (e.g. `us-east1` / `us-east1-b`). |
| Cluster create: *zone does not have enough resources* | Temporary capacity shortage in that zone. Change `ZONE` (e.g. `us-central1-b`/`-c`/`-f`) and re-run. |
| Push fails: *"tag … is immutable"* | Happens only if a tag was pushed outside the pipeline. The pipeline checks first and reuses the existing tag. |
| Pods `ImagePullBackOff` | The node SA is missing `artifactregistry.reader` on the repo. Re-run `gcp-setup.sh` (step 4). |
| `helm test` pod `ImagePullBackOff` on `busybox` | Private nodes have no internet without Cloud NAT. Check `gcloud compute routers nats list --router ebayshopping-router --region us-central1`. |
| Ingress has no IP / `kubectl describe ingress` shows *static IP not found* | `ebayshopping-ip` must be a **global** address with exactly the name in `values-prod.yaml`. |
| Public URL returns **502** for several minutes after the first deploy | Normal while Google programs the LB and health checks go green. The pipeline step waits for it. If it lasts more than 15 minutes: `kubectl describe ingress ebayshopping -n prod` and check the backend health status. |
| `kubectl`/`helm` from Cloud Shell: `dial tcp <control-plane-ip>:443: i/o timeout` | `get-credentials` wrote the IP endpoint, which authorized networks block. Re-fetch with `--dns-endpoint`: `gcloud container clusters get-credentials ebayshopping-gke --zone us-central1-a --dns-endpoint`. |
| Deploy fails: `kubernetes cluster unreachable ... i/o timeout` | The cluster's DNS-based endpoint is off, so the runner can only try the IP endpoint, which authorized networks block. Fix: `gcloud container clusters update ebayshopping-gke --zone us-central1-a --enable-dns-access` (the setup script does this from now on). |
| Deploy fails: `Permission denied on cluster ... container.clusters.connect` | The DNS endpoint needs that permission. Re-run `gcp-setup.sh` step 7, or grant `roles/container.developer` to the deployer SA. |
| Trivy fails the build | That's it working. Bump the base image or dependency it names (Dependabot usually already has a PR). If there's truly no fix, document it in `.trivyignore` with a reason and a re-check date. |
| `code scanning is not enabled` on SARIF upload | Repo **Settings → Code security → Code scanning → enable** (free on public repos). |
| Decommission: VPC delete fails *"resource is in use"* | An orphaned NEG or firewall rule remains. Re-run `gcp-decommission.sh`, which sweeps them again. |

---

*Setup guide by Sanjay Naidu — Project 5, September 2026.*
