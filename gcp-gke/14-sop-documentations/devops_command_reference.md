# DevOps, GCP, GKE, Kubernetes and Terragrunt Command Reference

A cleaned and categorized reference of commands extracted from the command history.

> **Note:** Replace placeholders such as `<PROJECT_ID>`, `<CLUSTER_NAME>`, `<NAMESPACE>`, and `<SERVICE_ACCOUNT_EMAIL>` with your actual values.

---

## Table of Contents

1. [GCP / gcloud](#1-gcp--gcloud)
2. [GKE Cluster Access](#2-gke-cluster-access)
3. [Kubernetes / kubectl](#3-kubernetes--kubectl)
4. [Terragrunt](#4-terragrunt)
5. [Terraform and Terragrunt Cleanup](#5-terraform-and-terragrunt-cleanup)
6. [Monitoring and Grafana](#6-monitoring-and-grafana)
7. [Secret Manager and Workload Identity Troubleshooting](#7-secret-manager-and-workload-identity-troubleshooting)
8. [Docker](#8-docker)
9. [Git](#9-git)
10. [Linux and Shell](#10-linux-and-shell)
11. [Development and Scripts](#11-development-and-scripts)
12. [Commands to Avoid / Invalid Examples](#12-commands-to-avoid--invalid-examples)

---

# 1. GCP / gcloud

## Authentication

```bash
gcloud auth login
gcloud auth list
```

## Projects

```bash
gcloud projects list

gcloud config set project <PROJECT_ID>
```

## IAM Policy Binding

```bash
gcloud projects add-iam-policy-binding <PROJECT_ID> \
  --member="user:<EMAIL>" \
  --role="<ROLE>"
```

## Enable GCP APIs

```bash
gcloud services enable iap.googleapis.com   --project=<PROJECT_ID>

gcloud services enable secretmanager.googleapis.com   --project=<PROJECT_ID>

gcloud services enable iamcredentials.googleapis.com   --project=<PROJECT_ID>
```

## Service Accounts

```bash
gcloud iam service-accounts list   --project=<PROJECT_ID>

gcloud iam service-accounts get-iam-policy   <SERVICE_ACCOUNT_EMAIL>

gcloud iam service-accounts delete   <SERVICE_ACCOUNT_EMAIL>   --project=<PROJECT_ID>
```

## Compute SSH Through IAP

```bash
gcloud compute ssh <BASTION_NAME>   --zone=<ZONE>   --project=<PROJECT_ID>   --tunnel-through-iap
```

## Cloud Storage

```bash
gcloud storage buckets list
```

---

# 2. GKE Cluster Access

## Get Kubernetes Credentials

```bash
gcloud container clusters get-credentials   <CLUSTER_NAME>   --zone=<ZONE>   --project=<PROJECT_ID>
```

## Describe Cluster

```bash
gcloud container clusters describe   <CLUSTER_NAME>   --region=<REGION>
```

## Check Workload Identity Pool

```bash
gcloud container clusters describe   <CLUSTER_NAME>   --region=<REGION>   --format="value(workloadIdentityConfig.workloadPool)"
```

---

# 3. Kubernetes / kubectl

## Cluster Information

```bash
kubectl get nodes
kubectl get nodes -o wide
kubectl get nodes -o yaml

kubectl cluster-info
```

## Namespaces

```bash
kubectl get ns

kubectl delete ns <NAMESPACE>
```

## Pods

```bash
kubectl get pods

kubectl get pods -n <NAMESPACE>

kubectl describe pod   <POD_NAME>   -n <NAMESPACE>

kubectl delete pod   <POD_NAME>   -n <NAMESPACE>

kubectl delete pod   -l app=<LABEL>   -n <NAMESPACE>
```

## Logs

```bash
kubectl logs -f   deploy/<DEPLOYMENT_NAME>   -n <NAMESPACE>

kubectl logs -f   <POD_NAME>   --tail=30   -n <NAMESPACE>
```

## Events

```bash
kubectl get events   --sort-by='.lastTimestamp'   -n <NAMESPACE>

kubectl get events   --sort-by='.lastTimestamp'   -n <NAMESPACE>   -w
```

## Services

```bash
kubectl get svc -n <NAMESPACE>

kubectl edit svc   -n <NAMESPACE>   <SERVICE_NAME>
```

## Deployments

```bash
kubectl edit deployments.apps   -n <NAMESPACE>   <DEPLOYMENT_NAME>

kubectl edit   -n <NAMESPACE>   deployments.apps   <DEPLOYMENT_NAME>
```

## Ingress

```bash
kubectl get ing -n <NAMESPACE>

kubectl get ingress -n <NAMESPACE>

kubectl get ingress   -n <NAMESPACE>   <INGRESS_NAME>

kubectl edit ingress   -n <NAMESPACE>   <INGRESS_NAME>
```

## Execute Commands Inside a Container

```bash
kubectl exec -it   <POD_NAME>   -n <NAMESPACE>   -- sh

kubectl exec -it   <POD_NAME>   -n <NAMESPACE>   -- bash

kubectl exec -it   deploy/<DEPLOYMENT_NAME>   -n <NAMESPACE>   -- sh
```

## Storage

```bash
kubectl get sc

kubectl get pvc
kubectl get pvc -n <NAMESPACE>

kubectl get pv

kubectl get persistentvolume
```

## Service Accounts

```bash
kubectl get sa

kubectl get sa -n <NAMESPACE>

kubectl get sa   -n <NAMESPACE>   <SERVICE_ACCOUNT>   -o yaml

kubectl describe sa   <SERVICE_ACCOUNT>   -n <NAMESPACE>
```

---

# 4. Terragrunt

## Initialize

```bash
terragrunt init

terragrunt init 
```

## Plan

```bash
terragrunt plan

terragrunt plan 
```

## Apply

```bash
terragrunt apply --auto-approve

terragrunt apply   -   --auto-approve
```

## Destroy

```bash
terragrunt destroy --auto-approve

terragrunt destroy --auto-approve
```

## Run All Modules

### Plan All

```bash
terragrunt run --all plan
```

### Plan Excluding Bootstrap

```bash
terragrunt run --all   --queue-exclude-dir "01-bootstrap"   plan
```

### Apply Excluding Bootstrap

```bash
terragrunt run --all   --queue-exclude-dir "01-bootstrap"   apply

terragrunt run --all   --queue-exclude-dir "01-bootstrap"   apply   --auto-approve
```

### Destroy Excluding Bootstrap

```bash
terragrunt run --all   --queue-exclude-dir "01-bootstrap"   destroy
```

### Exclude Multiple Directories

```bash
terragrunt run --all   --queue-exclude-dir "01-bootstrap"   --queue-exclude-dir "apps/frontend-web/"   plan
```

## Filter Specific Modules

```bash
terragrunt run --all   --filter "apps"   destroy

terragrunt run --all   --filter "apps/frontend-web/"   destroy

terragrunt run --all   --filter "05-monitoring"   destroy
```

## State Commands

```bash
terragrunt state list

terragrunt state refresh

terragrunt state pull

terragrunt output

terragrunt refresh

terragrunt state --help
```

## Render Configuration

```bash
terragrunt render
```

---

# 5. Terraform and Terragrunt Cleanup

## Remove Terragrunt Cache

```bash
rm -rf .terragrunt-cache
```

## Remove Terraform and Terragrunt Local Files

```bash
rm -rf   .terragrunt-cache   .terraform   .terraform.lock.hcl
```

## Remove All Terraform-Related Files

```bash
rm -rf .terraform*
```

## Clean Terragrunt Cache Recursively

```bash
find .   -name ".terragrunt-cache"   -type d   -exec rm -rf {} +
```

---

# 6. Monitoring and Grafana

## Get Monitoring Resources

```bash
kubectl get pods -n monitoring

kubectl get svc -n monitoring

kubectl get events   --sort-by='.lastTimestamp'   -n monitoring   -w

kubectl get pvc -n monitoring

kubectl get pv
```

## Port Forward Grafana

```bash
kubectl port-forward   svc/kube-prometheus-stack-grafana   3000:80   -n monitoring
```

## Retrieve Grafana Admin Password

```bash
kubectl get secret   --namespace monitoring   kube-prometheus-stack-grafana   -o jsonpath="{.data.admin-password}"   | base64 --decode
```

---

# 7. Secret Manager and Workload Identity Troubleshooting

## List Secrets

```bash
gcloud secrets list   --project=<PROJECT_ID>
```

## Check CSI Drivers

```bash
kubectl get csidrivers

kubectl get csidriver
```

## Check SecretProviderClass

```bash
kubectl get secretproviderclass -A

kubectl get secretproviderclass   <SECRET_PROVIDER_CLASS>   -n <NAMESPACE>   -o yaml
```

## Check Secret Store CSI Pods

```bash
kubectl get pods   -n kube-system   -l app=secrets-store-csi-driver   -o wide
```

## Check Kubernetes Service Account

```bash
kubectl describe sa   <KSA_NAME>   -n <NAMESPACE>
```

## Check Google Service Accounts

```bash
gcloud iam service-accounts list   --project=<PROJECT_ID>
```

## Validate Mounted Secrets Inside a Pod

```bash
kubectl exec -it   deploy/<DEPLOYMENT_NAME>   -n <NAMESPACE>   -- sh
```

Then inspect the mounted secret path:

```bash
ls -la /mnt/secrets
```

---

# 8. Docker

## Docker Compose

```bash
docker-compose up

docker-compose build
```

## Container Management

```bash
docker ps

docker run -it --rm   <IMAGE_NAME>   sh

docker run -it   <IMAGE_NAME>

docker container run   --image <IMAGE_NAME>   -it   -- bash
```

## Tag an Image

```bash
docker tag   <LOCAL_IMAGE>   <REPOSITORY>:<TAG>
```

## Push an Image

```bash
docker push   <REPOSITORY>:<TAG>
```

---

# 9. Git

```bash
git status

git add .

git branch

git push

git push --set-upstream   origin   <BRANCH_NAME>
```

---

# 10. Linux and Shell

## Navigation

```bash
cd <DIRECTORY>

cd ..

cd ../../

cd <ABSOLUTE_PATH>

cd ~/
```

## List Files

```bash
ls
```

## View Directory Tree

```bash
tree .
```

## Create Directory Structure

```bash
mkdir -p <PATH>
```

## Move or Rename

```bash
mv <SOURCE> <DESTINATION>
```

## Search Configuration Files

```bash
grep -R "bucket" terragrunt.hcl

grep -R "remote_state\|bucket" ../../../../

grep -R "bucket" .   --include="*.hcl"   --include="*.tf"
```

## Permissions

```bash
chmod +x scripts/create_client.sh
```

## Terminal

```bash
clear

history
```

---

# 11. Development and Scripts

## Open VS Code

```bash
code .
```

## View or Edit Files

```bash
cat <FILE_NAME>

vim <FILE_NAME>
```

## Run Client Creation Script

```bash
chmod +x scripts/create_client.sh

./scripts/create_client.sh   <CLIENT_NAME>   <ENVIRONMENT>   <PROJECT_ID>
```

## Run Python Scaffolding Script

```bash
python3 scripts/scaffold_client.py   <CONFIG_FILE>
```

Example:

```bash
python3 scripts/scaffold_client.py   12-platform-config/clients/client-b/infra/prod.yaml
```

---

# 12. Commands to Avoid / Invalid Examples

The following appeared to be incomplete, invalid, or typo-based attempts and should not be used as reference commands:

```text
docker run -
ocker run ...
docker run -image ...
node:alphine
cd cd gcp-gke/...
terragrunt plan --auto-approve
terragrunt p --backend-bootstrap
```

---

# Suggested Workflow

For a single Terragrunt module:

```text
1. terragrunt init
2. terragrunt plan
3. terragrunt apply --auto-approve
4. terragrunt output / terragrunt state list
5. terragrunt destroy --auto-approve
```

For all modules except bootstrap:

```text
terragrunt run --all   --queue-exclude-dir "01-bootstrap"   plan
```

Before troubleshooting Terraform or Terragrunt state issues:

```bash
find .   -name ".terragrunt-cache"   -type d   -exec rm -rf {} +

rm -rf .terraform .terraform.lock.hcl
```

Then initialize again:

```bash
terragrunt init
terragrunt plan
```

---

# Important Safety Note

Commands using `destroy`, `delete`, or `rm -rf` can remove infrastructure, Kubernetes resources, or local files. Always verify the current directory, project, namespace, and target resource before running them.

---

Last updated from the provided command history.
