Here is a complete, production-ready `README.md` file for your Docker setup. You can save this directly in your repository root as `README.md`.

---

# GCP Infrastructure & GitOps Runner Container

This directory contains a containerized environment pre-configured with all the necessary CLI tools and dependencies to run your multi-tenant GKE infrastructure framework using **Terraform**, **Terragrunt**, **Google Cloud SDK (`gcloud`)**, **`kubectl`**, **`helm`**, and **Python**.

---

## 🛠️ Included Tools & Stack

* **Python 3.11** (with `PyYAML` and `requests` for platform scaffolding and parsing scripts)
* **Terraform** (`v1.6.6`)
* **Terragrunt** (`v0.55.0`)
* **Google Cloud CLI (`gcloud`)**
* **`kubectl`** (latest stable release)
* **Helm** (v3)

---

## 🚀 Getting Started

### Prerequisites

* Ensure you have [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/) installed on your host machine.
* Authenticated with Google Cloud on your host machine at least once so your credentials exist under `~/.config/gcloud`.

---

## 📦 Usage Guide

### 1. Build the Container

Build the Docker image using Docker Compose. The `no-cache` flag ensures all dependencies download cleanly:

```bash
docker-compose build --no-cache

```

### 2. Open an Interactive Container Session

Launch the container interactively. This mounts your repository root directly to `/workspace` inside the container and shares your host's GCP credentials:

```bash
docker-compose run --rm infra-runner

```

### 3. Verify the Environment

Once inside the container shell, you can verify that all toolchains are correctly configured:

```bash
terraform --version
terragrunt --version
kubectl version --client
python3 --version
gcloud auth list

```

---

## ⚙️ Workflow Examples

### Running Scaffolding Scripts

Generate client infrastructure layouts or application configurations using the Python automation scripts:

```bash
python3 gcp-gke/15-scripts/scaffold_client.py gcp-gke/12-platform-config/clients/hdfc-bank/dev/infra/dev.yaml

```

### Running Terragrunt Pipelines

Navigate to your live client environment path and execute your infrastructure blueprint:

```bash
cd gcp-gke/03-live/clients/hdfc-bank/dev
terragrunt run --all plan
terragrunt run --all apply

```

---

## 💡 Troubleshooting

### Git "Dubious Ownership" Error

Because your repository is mounted from the host into the container, Git may occasionally flag ownership differences. If you encounter a `dubious ownership in repository` error when running Terragrunt functions, run this command once inside the container (already handled if added to the Dockerfile):

```bash
git config --global --add safe.directory /workspace

```