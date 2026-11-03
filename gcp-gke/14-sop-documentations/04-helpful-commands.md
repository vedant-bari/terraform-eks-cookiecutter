Here is the comprehensive command runbook segregated by order of execution and workflow process, derived directly from the infrastructure deployment patterns and terminal history. You can save this as an `.md` file for your team.

---

# Multi-Tenant GKE Infrastructure Deployment & Operations Runbook

This guide outlines the complete operational lifecycle for provisioning multi-client, multi-environment infrastructure on GKE using Terragrunt, Terraform, and Kubernetes.

---

## Phase 1: Authentication & Cluster Access

Before interacting with GCP or Kubernetes, ensure your user profile has appropriate permissions and context credentials.

* Authenticate with Google Cloud SDK:


```bash
gcloud auth login

```


* Fetch GKE cluster credentials for your target environment:


```bash
gcloud container clusters get-credentials gke-<client-name>-<env> --zone=<zone/region> --project=<project-id>

```


*(Example: `gcloud container clusters get-credentials gke-hdfc-bank-prod --zone asia-south1 --project eks-terraform`)*


---

## Phase 2: Platform Configuration & Scaffolding

Use Python scaffolding scripts to dynamically generate client directory structures, infrastructure specifications, and application value files.

* Scaffold client infrastructure configurations:


```bash
python3 15-scripts/scaffold_client.py 12-platform-config/clients/<client-name>/infra/<env>.yaml

```


* Scaffold monitoring configurations:


```bash
python3 15-scripts/scaffold_monitoring.py 12-platform-config/clients/<client-name>/monitoring-and-logging/<env>.yaml

```


* Scaffold application deployment values:


```bash
python3 15-scripts/03-scaffold_apps.py 12-platform-config/clients/<client-name>/apps/<app-name>-values.yaml

```



---

## Phase 3: Bootstrap & Remote State Management

Manage GCP remote state storage buckets and handle backend configurations safely.

* Create a manual GCS state bucket if required:


```bash
gcloud storage buckets create gs://<bucket-name> --project=<project-id> --location=<region> --uniform-bucket-level-access

```


* Bootstrap the Terragrunt backend state configuration automatically:


```bash
terragrunt init --backend-bootstrap

```


* Import an existing orphaned GCS state bucket into the Terragrunt state file:


```bash
terragrunt import google_storage_bucket.tf_state <bucket-name>

```



---

## Phase 4: Infrastructure Provisioning (Terragrunt Execution)

Navigate to the live environment directory to plan, apply, or destroy your stacked infrastructure modules.

* Navigate to a live client environment path:


```bash
cd gcp-gke/03-live/clients/<client-name>/<env>

```


* Run a dry-run execution plan across all modules in dependency order:


```bash
terragrunt run --all plan

```


* Apply all infrastructure layers (VPC, GKE, Storage, Monitoring, Apps):


```bash
terragrunt run --all apply

```


* Apply with automatic approval:


```bash
terragrunt run --all apply --auto-approve

```


* Destroy the environment stack safely when cleaning up:


```bash
terragrunt run --all destroy

```



---

## Phase 5: Kubernetes Diagnostics & Validation (`kubectl`)

Verify deployment states, track rollout events, and troubleshoot ingress or cluster issues.

* Verify cluster node status:


```bash
kubectl get nodes

```


* Check active storage classes in the cluster:


```bash
kubectl get sc

```


* Stream chronological events within a namespace to debug failures (e.g., monitoring or apps):


```bash
kubectl get events --sort-by='.lastTimestamp' -n <namespace> -w

```


* Retrieve the Grafana admin password from the monitoring stack secret:


```bash
kubectl get secret --namespace monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode

```


* Port-forward the Grafana dashboard locally for browser testing:


```bash
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring

```



---

## Phase 6: Maintenance & Troubleshooting Commands

Clear local caches or resolve state mismatches when infrastructure runs into deployment blocks.

* Recursively clear all local Terragrunt caches across subdirectories:


```bash
find . -name ".terragrunt-cache" -type d -exec rm -rf {} +

```


* Deep clean Terraform and Terragrunt cache files in a specific layer:


```bash
rm -rf .terragrunt-cache .terraform .terraform.lock.hcl

```