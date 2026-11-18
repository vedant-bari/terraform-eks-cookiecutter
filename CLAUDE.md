# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository shape

Two independent Terraform + Terragrunt platform blueprints live side by side; they share no code:

- `gcp-gke/` — GKE platform. This is the actively developed, hardened half. **It has its own [gcp-gke/CLAUDE.md](gcp-gke/CLAUDE.md) with commands, architecture and validator rules — read it before touching anything under `gcp-gke/`.**
- `aws-eks/` — EKS platform, being rebuilt phase by phase as the AWS counterpart of `gcp-gke/` (see below).

Both halves follow the same pattern: per-client/env **YAML config is the source of truth** → thin **Terragrunt live units** decode that YAML in a `root.hcl` and map it into inputs → reusable **Terraform modules**. Live units reference modules via `${get_repo_root()}/<half>/...`, so `get_repo_root()` is this directory, not the subfolder.

Editing files never touches cloud resources; only running Terragrunt does. Do not run `terragrunt apply`/`destroy` or `run --all apply` yourself.

## aws-eks

The old half-migrated tree was removed (recoverable from git history). The new tree mirrors `gcp-gke/`'s layout, so read [aws-eks/README.md](aws-eks/README.md) first. Phases 0 (bootstrap, scripts, tooling) and 1 (`01-network` → `03-modules/02-vpc`) exist so far.

**Config and generated files**
- **Config:** `aws-eks/01-config/clients/<client>/<env>/infra/<env>.yaml`, with keys `aws.{account_id,region,profile,assume_deploy_role,tags}`, `bootstrap.*`, `vpc.*` and `budget.*`. Each block is exposed by `root.hcl` as `config.<block>`.
- **Missing or invalid YAML is a hard error** in `aws-eks/04-live/root.hcl`. There is no `try(..., {})` fallback.
- **`root.hcl` generates `provider.tf` as well as `backend.tf`.**
  - The S3 backend uses `use_lockfile`. Its key is `aws-eks/<client>/<env>/<layer-key>/terraform.tfstate`, taken from the `state_layer_keys` map.
  - The aws provider gets `allowed_account_ids`, `default_tags`, and `assume_role` into the deploy role created by `00-bootstrap`; `00-bootstrap` itself doesn't assume it.
- **Modules must not declare `provider "aws"`.**
- **Names are derived:**
  - prefix `<client>-<env>`
  - state bucket `<client>-<env>-tfstate-<account_id>`
  - deploy role `<client>-<env>-terraform-deploy`

**Offline validation:** set `AWS_EKS_OFFLINE=true`. It swaps in a throwaway local backend:
```
AWS_EKS_OFFLINE=true terragrunt --working-dir aws-eks/04-live/clients/amex/prod/<layer> run -- validate
```

**Scripts** (all in `aws-eks/02-scripts/`):
- **Shared helpers:** `lib/common.sh` holds the `ALL_LAYERS` order, the config loader, and the account and bucket checks. `lib/read_env_config.py` must derive names exactly as `root.hcl` does.
- **`plan-env.sh` / `apply-env.sh` / `destroy-env.sh`** are ports of the gcp-gke scripts: saved plans, a manifest with the account ID, SHA-256 checks, type-to-confirm. They skip layers that don't exist yet.
- **`deploy-env.sh`** works differently from gcp-gke: it plans → shows → confirms → applies one layer at a time, for fresh environments.
- **`bootstrap/01-create-bootstrap-bucket.sh <client> <env>`** reads everything from the YAML. `00-bootstrap` then adopts the bucket through an `import` block.

**Runbook:** `aws-eks/00-documentation/deployment/BOOTSTRAP.md`.

**Pinned tool versions** (with SHA-256) are in both `aws-eks/08-docker/Dockerfile` and `aws-eks/02-scripts/bootstrap/install-prerequisites.sh`. Keep the two in sync.

## Repo-wide notes

- `.gitignore` excludes `*.tfplan`, `.gke-plans/`, `*.zip`, `*.tfstate*`, `*.auto.tfvars.json` and `.terragrunt-cache/`; saved plans and state must never be committed.
- Infra YAML values marked `CHANGE_ME` (account ID `000000000000`, profile, `Owner`/`CostCenter` tags, budget) are placeholders the user fills in. Do not invent real values.
