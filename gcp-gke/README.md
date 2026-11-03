# Cloud Platform Kubernetes Blueprint: Operations & Deployment Guide

This repository contains a production-grade, modular Infrastructure-as-Code (IaC) and GitOps-ready platform blueprint using **Terraform, Terragrunt, GKE, and Helm**. It provisions a cost-optimized R&D environment complete with native **Workload Identity**, **Google Secret Manager CSI integration**, and secure application deployment lifecycles.

---

## 1. Architecture Flow & Logic

The platform is built on a decoupled, DRY (Don't Repeat Yourself) design pattern using Terragrunt to pass inputs down to standardized Terraform modules.

### The End-to-End Workflow:

1. **Infrastructure Provisioning (`04-gke`, `08-iam-secrets`):**
* Terragrunt reads the environment-wide specifications from a centralized `dev.yaml` file.
* Terraform provisions a GKE cluster with **Workload Identity** and the **Secret Manager CSI Driver add-on** enabled natively.
* The `iam-secrets` module declares Google Service Accounts (GSAs), binds them to the Kubernetes Service Account (KSA) via Workload Identity, and populates Google Secret Manager with required credentials.


2. **Application Deployment (`frontend-web`):**
* Helm takes a generic application chart and deploys the workload alongside a `SecretProviderClass` template.
* At runtime, the GKE **Secret Store CSI Driver** (`secrets-store-gke.csi.k8s.io`) intercepts pod startup, authenticates via Workload Identity, fetches secrets directly from Secret Manager, and mounts them as secure in-memory files at `/mnt/secrets/`.



---

## 2. Repository Structure

```text
gcp-gke/
├── 01-bootstrap/               # State bucket & base Terraform backend setup
├── 02-modules/
│   ├── 04-gke/                 # Reusable GKE cluster module
│   └── 08-iam-secrets/         # Reusable IAM, Workload Identity, & Secret Manager module
├── 03-live/
│   └── clients/
│       └── client-a/
│           └── dev/            # Live environment entry points
│               ├── 04-gke/terragrunt.hcl
│               └── iam-secrets/terragrunt.hcl
├── 12-platform-config/
│   └── clients/
│       └── client-a/
│           ├── dev.yaml        # Infrastructure source of truth
│           └── apps/
│               └── frontend-web-values.yaml # App-specific values & secrets
└── 13-helm-charts-app/
    └── generic-app/            # Universal Helm chart for applications

```

---

## 3. Client Configuration Guide (`YAML` Files)

To keep configurations clean, all environment parameters and application secrets are externalized into YAML files.

### A. Infrastructure Configuration (`dev.yaml`)

This file dictates the control plane, machine sizing, and cluster add-ons for the client environment.

**File Location:** `gcp-gke/12-platform-config/clients/client-a/dev.yaml`

```yaml
environment: "dev"
gcpProject: "eks-terraform"
region: "us-central1"

gke:
  cluster_name: "gke-client-a-dev"
  cluster_version: "1.35.6-gke.1710000"
  release_channel: "REGULAR"
  machine_type: "e2-medium"             # Cost-optimized 2 vCPU / 4 GB RAM instance
  node_count: 1                         # Single node for R&D
  disk_size_gb: 30                      # Minimal disk size
  enable_autoscaling: true
  min_nodes: 1
  max_nodes: 2
  delete_protection: false
  enable_filestore_csi: true
  secretManagerEnabled: true
  workloadIdentityEnabled: true
  cluster_addons:
    http_load_balancing: true
    horizontal_pod_autoscaling: false
    gce_csi_driver: true

```

### B. Application Configuration (`frontend-web-values.yaml`)

This file defines Helm chart values, application workloads, persistence, and the Secret Manager secret mappings.

**File Location:** `gcp-gke/12-platform-config/clients/client-a/apps/frontend-web-values.yaml`

```yaml
gcpProject: "eks-terraform"
namespace:
  create: false
  name: "dev-frontend"

serviceAccount:
  create: true
  name: "frontend-web-ksa"

googleServiceAccountName: "frontend-web-gsa"

image:
  repository: "nginx"
  tag: "alpine"
  pullPolicy: "IfNotPresent"

service:
  targetPort: 80

persistence:
  enabled: true
  mountPath: "/usr/share/nginx/html/storage"

secretManager:
  enabled: true
  driver: "secrets-store-gke.csi.k8s.io"
  secrets:
    - secretId: "prod-db-password"
      secretValue: "my-super-secret-password-123"
      key: "DB_PASSWORD"
    - secretId: "prod-api-key"
      secretValue: "my-super-secret-api-key-456"
      key: "API_KEY"

```

---

## 4. Step-by-Step Deployment Guide

### Prerequisites

Ensure you have the following tools installed and authenticated on your local machine:

* `gcloud` CLI (authenticated with permissions to manage GCP projects and GKE)
* `terraform` (v1.5+ recommended)
* `terragrunt`
* `kubectl`
* `helm`

---

### Step 1: Initialize Bootstrap Infrastructure

The bootstrap module sets up your remote state storage bucket. *(Note: This is typically run once per cloud account).*

```bash
cd gcp-gke/01-bootstrap
terragrunt init
terragrunt apply

```

---

### Step 2: Deploy Core Infrastructure (GKE & IAM/Secrets)

Navigate to your client's live environment directory to spin up the network, GKE cluster, and Secret Manager configuration.

```bash
cd gcp-gke/03-live/clients/client-a/dev
terragrunt run-all apply

```

*Terragrunt will automatically resolve dependencies, initializing the GKE cluster first, ensuring Workload Identity pools and CSI drivers are online, and then provisioning GCP secrets and IAM bindings.*

---

### Step 3: Configure `kubectl` Context

Once the GKE cluster is provisioned, configure your local Kubernetes context to point to your new cluster:

```bash
gcloud container clusters get-credentials gke-client-a-dev --region us-central1

```

---

### Step 4: Deploy the Application via Helm / Terragrunt

If your application live module is set up alongside your infrastructure directories, apply it:

```bash
cd gcp-gke/03-live/clients/client-a/dev/apps/frontend-web # (or equivalent app path)
terragrunt apply

```

---

## 5. Validation & Testing

### Verify Secret Mounts Inside the Pod

To confirm that the Secret Store CSI driver has successfully authenticated via Workload Identity and mounted your secrets, execute an in-pod inspection script:

```bash
kubectl exec -it deploy/frontend-web-generic-app -n dev-frontend -- sh -c '
  echo "--- Checking Mounted Secrets ---"
  ls -la /mnt/secrets
  echo ""
  echo "--- Reading DB_PASSWORD ---"
  cat /mnt/secrets/DB_PASSWORD
'

```

---

## 6. Observability & Alerting Recommendations

For enhanced tracing and log-based error alerting (such as capturing 5XX status codes or exceptions) in your GKE cluster:

* **Tracing & APM:** Deploy **SigNoz** via Helm for an open-source, OpenTelemetry-native platform tracking traces, metrics, and logs in a unified UI.
* **Log-Based Alerting:** Implement **Grafana Loki** paired with **Grafana Alerting**. You can write LogQL queries (e.g., matching error logs or HTTP `5xx` spikes) to trigger notifications directly to Slack or Webhooks.

---

## 7. Teardown & Cleanup

To safely tear down your client infrastructure while leaving the foundational `bootstrap` state bucket intact:

1. Navigate to your client's live environment directory:
```bash
cd gcp-gke/03-live/clients/client-a/dev

```


2. Execute the recursive destroy command:
```bash
terragrunt run-all destroy

```


*Terragrunt will automatically tear down workloads, Helm releases, GKE node pools, clusters, and IAM configurations in correct reverse dependency order.*