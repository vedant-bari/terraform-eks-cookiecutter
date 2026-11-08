# GKE Platform Blueprint

A reusable Google Cloud platform blueprint built with Terraform, Terragrunt, GKE, Helm, and GitOps-oriented deployment patterns.

> **Repository status:** The AMEX configuration under `04-live/clients/amex/prod` is retained as a historical test deployment. The infrastructure created from it was deleted. This migration is a repository-structure and reference update only; it does not run Terraform, change cloud resources, or remove remote state objects.

## Repository layout

```text
gcp-gke/
├── 00-documentation/       # Architecture, deployment, operations, troubleshooting
├── 01-config/              # Client and environment YAML configuration
├── 02-scripts/             # Bootstrap, scaffolding, validation, templates
├── 03-modules/             # Reusable Terraform modules
├── 04-live/                # Terragrunt client/environment entry points
├── 05-helm-charts/         # Reusable Helm charts
├── 06-examples/            # Infrastructure, application, monitoring examples
├── 07-tests/               # Read-only static validation
├── 08-docker/              # Local tooling/container definitions
└── 17-tmp-backup/          # Historical backup; preserved unchanged
```

## Live environment layout

The retained AMEX test configuration uses the following layer names:

| Layer | Purpose |
|---|---|
| `00-bootstrap` | Remote state bucket foundation |
| `01-network` | VPC and subnet resources |
| `02-gke` | GKE cluster |
| `03-artifact-registry` | Container image registry |
| `04-storage` | Storage configuration |
| `05-monitoring` | Reserved for a future optional layer; not part of the retained AMEX deployment |
| `06-jenkins` | Jenkins platform components |
| `07-applications` | Application workloads |

The dependency graph, not the numeric prefixes alone, determines execution order. GKE depends on Network; Artifact Registry, Storage, and Jenkins depend on GKE; Applications depend on GKE, Artifact Registry, and Jenkins.

## Configuration

Environment configuration is stored under:

```text
01-config/clients/<client>/<environment>/
├── infra/<environment>.yaml
├── apps/
└── jenkins/
```

Keep credentials out of committed YAML. Use Secret Manager references or another approved secret-injection mechanism, and supply sensitive values through the relevant secure runtime integration.

## Terraform state identity

Terragrunt state prefixes now use stable logical layer identifiers rather than the physical live-directory name:

```text
gcp-gke/<client>/<environment>/<logical-layer>/terraform.tfstate
```

This avoids changing state identity when a live folder is renamed. The previous path-derived prefix is historical. No state object is moved or deleted by this repository migration; if the old test state still exists in GCS, it remains untouched.

## Scaffolding

Scripts are grouped under `02-scripts`:

- `bootstrap/`: prerequisite and bootstrap utilities
- `scaffolding/`: client, application, and monitoring layout generators
- `templates/`: Terragrunt templates used by scaffolding
- `validation/`: command references and validation helpers

Example:

```bash
python3 gcp-gke/02-scripts/scaffolding/02-scaffold_client.py \
  gcp-gke/01-config/clients/<client>/<environment>/infra/<environment>.yaml
```

Review generated files before running Terragrunt. The scaffolders create configuration files; they do not provision infrastructure.

## Validation expectations

Before using a client environment, verify:

1. YAML files parse and contain the required client/environment fields.
2. Terragrunt include paths, module sources, and dependency paths resolve.
3. Terraform module inputs match the selected environment configuration.
4. A reviewed Terragrunt plan matches the intended change.

The repository static validation does not run Terraform plans or cloud operations. Use the saved-plan workflow documented in `00-documentation/deployment/GKE_TERRAFORM_DEPLOYMENT_RUNBOOK.md`; do not use `terragrunt run --all apply` as a deployment shortcut.

## Saved-plan workflow

Run the read-only checks with `bash gcp-gke/07-tests/run_tests.sh`. Create plans with `bash gcp-gke/02-scripts/plan-env.sh <client> <environment>`, review every saved plan, then apply only the exact saved plans with `bash gcp-gke/02-scripts/apply-env.sh <client> <environment> --plan-dir <directory> --approve`. For fresh environments, use `--layer` and plan/apply in dependency order so downstream units consume real outputs. Destruction is plan-only by default and requires explicit `--destroy` plus typed confirmation. Bootstrap/state bucket is excluded.

## Historical documentation

Operational procedures are retained under `00-documentation`. In particular, review `operations/BOOTSTRAP_DELETION.md` carefully before following it: it contains destructive state-cleanup guidance and is preserved for historical reference, not endorsed as a routine migration step.
