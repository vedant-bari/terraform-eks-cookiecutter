# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository shape

Two independent Terraform + Terragrunt platform blueprints live side by side; they share no code:

- `gcp-gke/` — GKE platform. This is the actively developed, hardened half. **It has its own [gcp-gke/CLAUDE.md](gcp-gke/CLAUDE.md) with commands, architecture and validator rules — read it before touching anything under `gcp-gke/`.**
- `aws-eks/` — EKS platform, being rebuilt phase by phase as the AWS counterpart of `gcp-gke/` (see below).

Both halves follow the same pattern: per-client/env **YAML config is the source of truth** → thin **Terragrunt live units** decode that YAML in a `root.hcl` and map it into inputs → reusable **Terraform modules**. Live units reference modules via `${get_repo_root()}/<half>/...`, so `get_repo_root()` is this directory, not the subfolder.

Editing files never touches cloud resources; only running Terragrunt does. Do not run `terragrunt apply`/`destroy` or `run --all apply` yourself.

## aws-eks

The old half-migrated tree was removed (recoverable from git history). The new tree mirrors `gcp-gke/`'s layout, so read [aws-eks/README.md](aws-eks/README.md) first. Phases 0 (bootstrap, scripts, tooling), 1 (`01-network` → `03-modules/02-vpc`) 2 (`02-eks` → `03-modules/04-eks`) 3 (`03-ecr` → `11-ecr`, `04-storage` → `07-storage-class`) 4 (`05-cluster-addons` → `09-cluster-addons`) 5 (`06-monitoring` → `05-monitoring`) and 6 (`07-jenkins` → `10-jenkins`) exist so far.

**Config and generated files**
- **Config:** `aws-eks/01-config/clients/<client>/<env>/infra/<env>.yaml`, with keys `aws.{account_id,region,profile,assume_deploy_role,tags}`, `bootstrap.*`, `vpc.*`, `eks.*`, `ecr.*`, `storage.*`, `cluster_addons.*`, `jenkins.*` and `budget.*`. Each block is exposed by `root.hcl` as `config.<block>`.
- **Missing or invalid YAML is a hard error** in `aws-eks/04-live/root.hcl`. There is no `try(..., {})` fallback.
- **`root.hcl` generates `provider.tf` as well as `backend.tf`.**
  - The S3 backend uses `use_lockfile`. Its key is `aws-eks/<client>/<env>/<layer-key>/terraform.tfstate`, taken from the `state_layer_keys` map.
  - The aws provider gets `allowed_account_ids`, `default_tags`, and `assume_role` into the deploy role created by `00-bootstrap`; `00-bootstrap` itself doesn't assume it.
- **Modules must not declare `provider "aws"`.** Modules that talk to the cluster declare their own `kubernetes`/`helm` provider with exec auth (`aws eks get-token --role-arn <deploy role>`), because EKS tokens last 15 minutes.
- **Version coupling:** `cluster_addons.cluster_autoscaler.image_tag` must match `eks.kubernetes_version` (variable validation enforces it), and the ASCP secrets driver is the EKS add-on `aws-secrets-store-csi-driver-provider`, not a Helm release.
- **Monitoring values** live in `01-config/.../monitoring-and-logging/<env>.yaml` and are kept identical to gcp-gke apart from `gp3` and the disabled EKS control-plane scrapes. A precondition fails if any `storageClass`/`storageClassName` there differs from the 04-storage class. `GRAFANA_ADMIN_PASSWORD` (12+ characters) must be exported to plan it.
- **Jenkins values** (`01-config/.../jenkins/<env>.yaml`) are a `templatefile()` template, so a literal dollar-brace must be escaped by doubling the dollar sign. In jenkins chart 5.x `persistence:` is top-level (gcp-gke nests it under `controller:`, where it is ignored).
- **ECR repositories are derived** from `apps/*.yaml` files with `ecr.enabled: true` (basename of `image.repository`), plus `ecr.additional_repositories`.
- **Names are derived:**
  - prefix `<client>-<env>`
  - state bucket `<client>-<env>-tfstate-<account_id>`
  - deploy role `<client>-<env>-terraform-deploy`
  - EKS cluster `<client>-<env>-eks`

**Live units that depend on another layer** allow mock outputs for `init`, `validate` and `plan`, so a fresh environment can be previewed.

**Offline validation:** set `AWS_EKS_OFFLINE=true`. It swaps in a throwaway local backend:
```
AWS_EKS_OFFLINE=true terragrunt --working-dir aws-eks/04-live/clients/amex/prod/<layer> run -- validate
```

**Scripts** (all in `aws-eks/02-scripts/`):
- **Shared helpers:** `lib/common.sh` holds the `ALL_LAYERS` order, the config loader, and the account and bucket checks. `lib/read_env_config.py` must derive names (bucket, cluster, deploy role) exactly as `root.hcl` does.
- **`destroy-env.sh`** refuses to destroy the cluster layers while Ingresses, LoadBalancer Services or PVCs remain (they own AWS resources outside Terraform state).
- **`plan-env.sh` / `apply-env.sh` / `destroy-env.sh`** are ports of the gcp-gke scripts: saved plans, a manifest with the account ID, SHA-256 checks, type-to-confirm. They skip layers that don't exist yet.
- **`deploy-env.sh`** works differently from gcp-gke: it plans → shows → confirms → applies one layer at a time, for fresh environments.
- **`bootstrap/01-create-bootstrap-bucket.sh <client> <env>`** reads everything from the YAML. `00-bootstrap` then adopts the bucket through an `import` block.

**Runbook:** `aws-eks/00-documentation/deployment/BOOTSTRAP.md`.

**Pinned tool versions** (with SHA-256) are in both `aws-eks/08-docker/Dockerfile` and `aws-eks/02-scripts/bootstrap/install-prerequisites.sh`. Keep the two in sync.

## Repo-wide notes

- `.gitignore` excludes `*.tfplan`, `.gke-plans/`, `*.zip`, `*.tfstate*`, `*.auto.tfvars.json` and `.terragrunt-cache/`; saved plans and state must never be committed.
- Infra YAML values marked `CHANGE_ME` (account ID `000000000000`, profile, `Owner`/`CostCenter` tags, budget) are placeholders the user fills in. Do not invent real values.
