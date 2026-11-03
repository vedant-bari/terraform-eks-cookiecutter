Here is comprehensive, production-ready documentation for your automated multi-application deployment pipeline. You can save this file as **`docs/app-deployment-pipeline.md`** in your repository.

---

# Automated Multi-App Deployment Pipeline Documentation

## 🚀 Overview

This pipeline provides an automated, scalable architecture for deploying Kubernetes applications to Google Kubernetes Engine (GKE) using **Terragrunt, Terraform, and Helm**.

Instead of manually editing infrastructure templates or re-running scaffolding scripts for every microservice, the architecture features **directory-based auto-discovery**. Dropping a client-specific values file into an application directory automatically triggers the provisioning of its namespace, Google Service Accounts (GSAs), Workload Identity bindings, Secret Manager secrets, and Helm releases.

---

## 📂 Architecture & Directory Structure

```text
cloud-platform-blueprint-kubernetes/
├── gcp-gke/
│   ├── 02-modules/
│   │   └── 06-app-deploy/             # Core Terraform deployment module
│   │       ├── main.tf
│   │       └── variables.tf
│   ├── 03-live/
│   │   └── clients/
│   │       └── client-c/
│   │           └── prod/
│   │               └── 06-apps/       # Generated Terragrunt layer
│   │                   └── terragrunt.hcl
│   ├── 12-platform-config/
│   │   └── clients/
│   │       └── client-c/
│   │           └── apps/              # 📥 Drop your YAML values files here!
│   │               ├── frontend-web-prod-values.yaml
│   │               └── backend-api-prod-values.yaml
│   └── 13-helm-charts-app/
│       └── generic-app/               # Reusable Helm chart
└── docs/
    └── app-deployment-pipeline.md

```

---

## 🛠️ Step-by-Step Guide: Deploying a New Application

### Step 1: Create Your Application Values File

Create a new YAML file inside the target client's application directory.

* **Path:** `gcp-gke/12-platform-config/clients/<client-name>/apps/<app-name>-values.yaml`
* **Sample Content (`frontend-web-prod-values.yaml`):**

```yaml
releaseName: frontend-web-prod
timeout: 600

apps:
  enabled: true   # Set to false to temporarily disable or tear down this app

namespace:
  create: true
  name: frontend-web-prod

# --- GCP IAM & WORKLOAD IDENTITY CONFIG ---
gcpProject: "eks-terraform"
googleServiceAccountName: "frontend-web-prod-gsa"

serviceAccount:
  create: true
  name: "frontend-web-prod-sa"
  annotations:
    iam.gke.io/gcp-service-account: "frontend-web-prod-gsa@eks-terraform.iam.gserviceaccount.com"

image:
  repository: nginx
  tag: "alpine"
  pullPolicy: IfNotPresent

service:
  enabled: true
  port: 80
  targetPort: 80
  type: ClusterIP

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80

# --- GCP SECRET MANAGER INTEGRATION ---
secretManager:
  enabled: true
  driver: "secrets-store-gke.csi.k8s.io"
  secrets:
    - secretId: "prod-db-password"
      secretValue: "my-super-secret-password-123"
      key: "DB_PASSWORD"

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 100m
    memory: 128Mi

```

### Step 2: Run the Scaffolding Script (If Initializing a New Client Layer)

If you are setting up the client environment for the first time, execute the scaffolding script to generate the underlying folder infrastructure and Terragrunt configuration:

```bash
python3 gcp-gke/scripts/scaffold_apps.py gcp-gke/12-platform-config/clients/client-c/infra/prod.yaml

```

*(Note: If the `06-apps` layer already exists, you can skip this step entirely. Simply dropping the values file in Step 1 is enough for subsequent updates!)*

### Step 3: Deploy via Terragrunt

Navigate to the client application live directory and execute the Terragrunt deployment command:

```bash
cd gcp-gke/03-live/clients/client-c/prod/06-apps

# Review the execution plan
terragrunt plan

# Apply the configuration
terragrunt apply

```

---

## ⚙️ Advanced Operations

### 1. Temporarily Disabling an Application

If you want to un-deploy an application without deleting its configuration file, edit its values file and set `apps.enabled` to `false`:

```yaml
apps:
  enabled: false

```

Run `terragrunt apply`. The pipeline will automatically evaluate the flag and clean up its Helm release, namespace, and associated cloud IAM/Secret bindings safely.

### 2. Adding Multiple Applications Simultaneously

You can drop multiple `.yaml` files into the client's `apps/` directory (e.g., `frontend-values.yaml`, `backend-values.yaml`, `worker-values.yaml`). The Terragrunt auto-discovery configuration automatically reads, JSON-encodes, and deploys all active files in parallel.

### 3. Tearing Down the Infrastructure

To completely destroy the applications layer and clean up all provisioned Kubernetes namespaces and GCP secrets for a client:

```bash
cd gcp-gke/03-live/clients/client-c/prod/06-apps
terragrunt destroy

```

---

## 📝 Quick Reference Commands

| Task | Command |
| --- | --- |
| **Plan App Changes** | `cd gcp-gke/03-live/clients/<client>/prod/06-apps && terragrunt plan` |
| **Deploy/Update Apps** | `cd gcp-gke/03-live/clients/<client>/prod/06-apps && terragrunt apply` |
| **Destroy Apps** | `cd gcp-gke/03-live/clients/<client>/prod/06-apps && terragrunt destroy` |
| **Full Environment Deploy** | `cd gcp-gke/03-live/clients/<client>/prod && terragrunt run-all apply` |