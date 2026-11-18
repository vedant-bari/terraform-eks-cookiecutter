# aws-eks

This is the AWS EKS counterpart of [`../gcp-gke`](../gcp-gke). It uses the same structure and the same workflow:
- YAML config in `01-config` is the source of truth.
- Thin Terragrunt units in `04-live` read that config.
- The units call reusable Terraform modules in `03-modules`.

> **Status:** it is being built phase by phase. Phases 0 (bootstrap and tooling), 1 (network), 2 (EKS), 3 (ECR, storage) and 4 (cluster add-ons) exist so far.

## Layout

| Path | Contents |
|---|---|
| `00-documentation/` | Runbooks. Start with [deployment/BOOTSTRAP.md](00-documentation/deployment/BOOTSTRAP.md) |
| `01-config/clients/<client>/<env>/` | Per-environment YAML: `infra/<env>.yaml`, later `apps/`, `jenkins/`, `monitoring-and-logging/` |
| `02-scripts/` | `plan-env.sh`, `apply-env.sh`, `deploy-env.sh`, `destroy-env.sh`, `bootstrap/`, `lib/` |
| `03-modules/` | Terraform modules. Numbers match the `gcp-gke` modules (`04-eks` ↔ `04-gke`, `11-ecr` ↔ `11-artifact-registry`) |
| `04-live/` | `root.hcl` and the live units under `clients/<client>/<env>/NN-*` |
| `08-docker/` | Pinned tooling container (AWS CLI, Terraform, Terragrunt, kubectl, Helm) |

## Layers

They run in dependency order. Every layer except bootstrap is created by the scripts.

| # | Live unit | Status |
|---|---|---|
| 00 | bootstrap: state bucket, deploy role, EBS default encryption | ✅ |
| 01 | network: VPC across 3 AZs, private/public subnets, NAT, flow logs to S3, S3 gateway endpoint | ✅ |
| 02 | eks: cluster, managed node group(s), access entries, KMS secrets encryption, managed add-ons with Pod Identity | ✅ |
| 03 | ecr: one repository per app image (`<client>-<env>/<image>`), scan on push, lifecycle policy | ✅ |
| 04 | storage: default encrypted gp3 StorageClass; encrypted EFS + `<client>-<env>-rwx` StorageClass | ✅ |
| 05 | cluster-addons: AWS Load Balancer Controller, Cluster Autoscaler (Helm, Pod Identity). Secrets driver (ASCP) is an EKS add-on in 02-eks | ✅ |
| 06 | monitoring | Phase 5 |
| 07 | jenkins | Phase 6 |
| 08 | applications | Phase 7 |

## Conventions

- **Client and environment** come from the live path. **Account, region, profile and tags** come from `infra/<env>.yaml`.
- **Nothing is hardcoded:** names are derived as `<client>-<env>-*`.
- **`root.hcl` generates two files:**
  - `backend.tf`: S3, `use_lockfile`, with state key `aws-eks/<client>/<env>/<layer-key>/terraform.tfstate`
  - `provider.tf`: region, `allowed_account_ids`, `default_tags`, and the deploy-role `assume_role` for every layer after bootstrap
- **Modules must not declare `provider "aws"`.**
- **Never apply Terragrunt from an unreviewed plan.** The scripts require a clean git tree and type-to-confirm for every layer.
