# GKE Terraform / Terragrunt Deployment Runbook

**Status:** Living operational document  
**Last updated:** 2026-11-09  
**Repository:** `vedant-bari/terraform-eks-cookiecutter`  
**Review branch:** `review/d1-d2-d3-d4-gke-hardening` (review only; do not merge without approval)  
**Scope:** `gcp-gke/04-live/clients/amex/prod` (retained test configuration)

> [!CAUTION]
> AMEX is retained test configuration and has since been provisioned for validation. Verify the live cluster, project, identity and state before operating it; do not treat this configuration as production-ready. This runbook does not authorize provisioning, state import/migration, or destruction. Obtain explicit approval before any infrastructure- or state-changing operation.

## 1. Safety rules

1. Confirm repository, branch, commit, and clean working tree before planning.
2. Verify the active Google identity, project, and intended GCS bucket.
3. Never allow deployment scripts to scaffold/overwrite reviewed HCL.
4. Never automatically import the bootstrap bucket. Bootstrap ownership is a separate state-management decision.
5. Saved plan files can contain sensitive data. Keep them outside Git, in a directory accessible only to the operator.
6. Review every saved plan before apply. Apply the exact saved plan; do not regenerate it during the apply step.
7. Destruction is plan-only by default. Applying destroy plans requires explicit `--destroy` and a per-layer confirmation.
8. Never run `state mv`, `state rm`, `force-unlock`, backend migration, or bucket deletion without separate approval and a recovery plan.
9. Do not treat mock-backed `validate` or `plan` output as evidence that real dependency outputs are correct.
10. Record commit, identity, project, timestamp, plan directory, and review decision.

## 2. Layout and execution order

Active live units:

1. `00-bootstrap` — special prerequisite; excluded from automated plan/apply because the GCS backend bucket must already exist before backend initialization.
2. `01-network`
3. `02-gke`
4. `03-artifact-registry`
5. `04-storage`
6. `05-monitoring` — Prometheus, Grafana, Alertmanager, Loki, Alloy and Tempo.
7. `06-jenkins`
8. `07-applications`

The AMEX monitoring layer is deployed after storage and before Jenkins in the orchestration order. Existing Jenkins and application layers are not changed by a monitoring-only plan. `17-tmp-backup` is historical and must remain untouched.

## 3. Prerequisites and preflight

Expected local tool versions previously used: Terragrunt 1.1.2 and Terraform 1.15.8. Verify the actual installed versions:

```bash
git status --short --branch
git branch --show-current
git rev-parse HEAD
terragrunt --version
terraform version
gcloud version
gcloud auth list
gcloud config get-value account
gcloud config get-value project
```

Review `gcp-gke/01-config/clients/amex/prod/infra/prod.yaml`. Current retained values include project `eks-terraform`, region `asia-south1`, zone `asia-south1-a`, and bucket `gcp-tf-state-amex-prod`; verify all values independently before any cloud operation.

The plan script performs a read-only bucket existence/access check with `gcloud storage buckets describe`. If the bucket is missing or inaccessible, stop. Create/approve the backend bucket through the documented bootstrap process first. Do not expect Terraform to create the bucket that its own remote backend requires.

## 4. Static repository validation

Run from the repository root:

```bash
bash gcp-gke/07-tests/run_tests.sh
```

This suite is intentionally read-only. It checks YAML duplicate keys, Python AST syntax, duplicate Terraform resource addresses, stable backend prefix mappings, live-unit/module/dependency paths, orchestration safety invariants, and shell syntax. Terraform/Terragrunt formatting and Helm lint checks run when the respective tools are installed.

The static suite does not replace authenticated provider initialization, real dependency-output validation, or remote plan review.

## 5. Create and review saved plans

Scaffolding is a separate, explicit operation. If a new client/environment needs generated Terragrunt files, review the YAML and run the appropriate generator manually. Inspect its diff before committing. Do not run scaffolding as part of planning or deployment.

Create plans (no apply/import/scaffolding):

```bash
bash gcp-gke/02-scripts/plan-env.sh amex prod
```

The script prints a plan directory under the system temporary directory. To choose a location, use an empty private directory:

```bash
install -d -m 700 /tmp/amex-prod-plans
bash gcp-gke/02-scripts/plan-env.sh amex prod --plan-dir /tmp/amex-prod-plans
```

The selected directory must be empty. The script records client, environment, branch, commit, and layer order in a manifest; saved plans are created with restrictive permissions. The plan set excludes bootstrap. If this is a fresh deployment and downstream dependency state does not yet exist, plan and apply one layer at a time so each next layer consumes real outputs from the preceding applied layer. Start with `--layer 01-network`, review and apply that saved plan, then repeat for `02-gke` and continue in dependency order. A full-stack plan is appropriate only when every required dependency has real state outputs.

Review every plan file. Example:

```bash
terragrunt --working-dir gcp-gke/04-live/clients/amex/prod/01-network run -- show -no-color /tmp/amex-prod-plans/01-network.tfplan
```

Inspect changes, replacements, deletions, IAM changes, network changes, GKE version/node-pool changes, and storage/registry changes. A plan that relies on mocks is not deployable evidence. Resolve mock-only dependencies before any approval to apply.

### 5.1 Deploy the observability layer only

The monitoring module consumes the GKE cluster outputs and uses the existing `standard-rwo` StorageClass for persistent data. It deploys:

- Prometheus and kube-state-metrics/node-exporter for cluster and workload metrics.
- Grafana with Prometheus, Loki and Tempo data sources; ingress remains disabled.
- Alertmanager with workload alert rules and a no-destination default receiver; external notifications are opt-in.
- Loki single-binary storage and Grafana Alloy DaemonSet for Kubernetes pod/event logs.
- Tempo single-binary mode with OTLP gRPC/HTTP receivers for application traces.

This is a small-cluster/test configuration: one replica for each stateful component, local PVC-backed Loki/Tempo storage and seven-day retention. It is not an HA or long-term archival design.

The monitoring module manages the `monitoring` namespace and creates the Grafana bootstrap Secret before installing Helm releases. No manual namespace or Secret creation is required. Alertmanager does not require a webhook URL for deployment: alerts are evaluated and visible in the Prometheus/Alertmanager interfaces, but no external notifications are sent until a destination is configured.

The environment file `01-config/clients/amex/prod/monitoring-and-logging/prod.yaml` defines:
- Grafana administrator username, Secret name and key names.
- Environment-variable name for the Grafana password (`GRAFANA_ADMIN_PASSWORD`).

Keep the actual secret values out of Git. Export them in the same terminal session used for planning and applying:

```bash
read -rsp "Grafana admin password (12+ characters): " GRAFANA_ADMIN_PASSWORD; echo
export GRAFANA_ADMIN_PASSWORD

```

The module writes the Grafana credentials into a Kubernetes Secret. **Terraform state will contain this Secret data even though the variable is marked sensitive.** Protect the GCS state bucket with least-privilege IAM, encryption and appropriate retention; keep saved plan files private. For environments where state operators must not be able to read this credential, use an external secret manager/External Secrets integration instead of Terraform-managed Kubernetes Secrets.

Validate the repository first:

```bash
bash gcp-gke/07-tests/run_tests.sh
```

Then create a monitoring-only plan. Do not plan or apply the other already-deployed layers:

```bash
PLAN_DIR="$(mktemp -d /tmp/amex-monitoring.XXXXXX)"
chmod 700 "$PLAN_DIR"
bash gcp-gke/02-scripts/plan-env.sh amex prod \\
  --layer 05-monitoring --plan-dir "$PLAN_DIR"

terragrunt --working-dir gcp-gke/04-live/clients/amex/prod/05-monitoring \\
  run -- show -no-color "$PLAN_DIR/05-monitoring.tfplan"
```

Review the saved plan for the namespace, Grafana Secret and four Helm releases. Confirm no unrelated infrastructure resources are changed. Investigate unexpected replacements, public load balancers/ingress, IAM changes, or unrelated infrastructure changes. Apply only after explicit approval:

```bash
bash gcp-gke/02-scripts/apply-env.sh amex prod \\
  --plan-dir "$PLAN_DIR" --approve
```

The script displays the saved plan again and requires typing `yes`. This applies only the monitoring layer recorded in the manifest.

After deployment, validate:

```bash
kubectl get pods -n monitoring -o wide
kubectl get pvc -n monitoring
kubectl get svc -n monitoring
kubectl get prometheusrules -n monitoring
kubectl get prometheus,alertmanager -n monitoring
kubectl get daemonset -n monitoring
```

Access Grafana locally (no public ingress):

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Open `http://localhost:3000` and sign in using the credentials stored in `grafana-admin-credentials`. Confirm Prometheus, Loki and Tempo data sources are healthy. Check Prometheus Alerts and Alertmanager for the configured crash-loop and unavailable-replica rules. External notifications are intentionally disabled by default; when a notification destination is selected, add its supported Alertmanager receiver configuration and credentials through a secret manager.

Applications must be instrumented with an OpenTelemetry SDK/agent to generate traces. Configure their OTLP exporter to use the in-cluster endpoint:

- gRPC: `tempo.monitoring.svc.cluster.local:4317`
- HTTP/protobuf: `http://tempo.monitoring.svc.cluster.local:4318`

Set `OTEL_SERVICE_NAME` and the SDK's OTLP exporter variables for the language/runtime. The Tempo service is internal-only; do not expose it directly because Tempo does not provide built-in authentication. Confirm traces in Grafana Explore using the Tempo data source. Logs are collected automatically by Alloy; metrics are scraped by Prometheus.

If the monitoring plan or deployment fails, stop and inspect the Helm release status/events before retrying. Do not run the full environment plan as a shortcut.

## 6. Apply reviewed saved plans

Only after every plan has been reviewed and explicitly approved, run:

```bash
bash gcp-gke/02-scripts/apply-env.sh amex prod --plan-dir /tmp/amex-prod-plans --approve
```

The script verifies the manifest, client/environment, branch, commit, and clean working tree. It displays each exact saved plan and asks for a per-layer confirmation. It applies the saved plan file; it does not run a new plan. If the source commit changes, create and review a fresh plan set.

Do not use `--auto-approve`. The saved-plan apply path intentionally has no unattended approval switch.

## 7. Full AMEX environment destroy-and-recreate lifecycle

This procedure is for an explicitly approved, complete teardown and recreation of the retained AMEX `prod` test environment. It covers all seven managed layers:

- `01-network`
- `02-gke`
- `03-artifact-registry`
- `04-storage`
- `05-monitoring`
- `06-jenkins`
- `07-applications`

The `00-bootstrap` layer and GCS state bucket are intentionally excluded. This is a destructive operation: application data, Filestore contents, PVC-backed data, registry images, and other resources may be deleted. Back up anything that must survive. Confirm the project, identity, region, and resource ownership before proceeding.

### 7.1 Preflight

Run from the repository root:

```bash
cd ~/workspace/nuclesteq/terraform-eks-cookiecutter

git status --short --branch
git branch --show-current
git rev-parse HEAD
gcloud auth list
gcloud config get-value account
gcloud config get-value project
gcloud storage buckets describe gs://gcp-tf-state-amex-prod
```

Use branch `review/d1-d2-d3-d4-gke-hardening` for this tested workflow. The scripts require a clean Git working tree and bind saved plans to the current branch and commit. Resolve any local changes deliberately before continuing; do not discard a lock file or other local change just to satisfy the clean-tree check.

Confirm that the configured project is `eks-terraform` and the region is `asia-south1`, or verify the current values in `gcp-gke/01-config/clients/amex/prod/infra/prod.yaml`. Do not proceed if the active identity/project or backend bucket is unexpected.

### 7.2 Generate destroy plans (no resources are destroyed)

Create a private plan directory and generate all seven destroy plans:

```bash
DESTROY_PLAN_DIR="$(mktemp -d /tmp/amex-prod-destroy.XXXXXX)"
chmod 700 "$DESTROY_PLAN_DIR"
echo "Destroy plan directory: $DESTROY_PLAN_DIR"

bash gcp-gke/02-scripts/destroy-env.sh amex prod \
  --plan-dir "$DESTROY_PLAN_DIR"
```

The script creates plans in reverse dependency order:

`07-applications` → `06-jenkins` → `05-monitoring` → `04-storage` → `03-artifact-registry` → `02-gke` → `01-network`.

It creates a manifest containing the client, environment, branch, commit, layer order, and plan checksums. It does not destroy resources unless the separate `--destroy` flag is supplied.

### 7.3 Review every destroy plan

Review all seven plans before authorizing destruction:

```bash
for layer in \
  07-applications \
  06-jenkins \
  05-monitoring \
  04-storage \
  03-artifact-registry \
  02-gke \
  01-network
do
  echo "========== DESTROY PLAN: $layer =========="
  terragrunt --working-dir \
    "gcp-gke/04-live/clients/amex/prod/$layer" \
    run -- show -no-color "$DESTROY_PLAN_DIR/$layer.tfplan"
done
```

Check each plan for unexpected resources, shared infrastructure, IAM changes, and destructive data loss. Pay particular attention to Filestore, PVC-backed data, Artifact Registry images, GKE, and network resources. Do not proceed if a plan is missing, uses unexpected dependencies, or includes resources outside the intended test environment.

### 7.4 Execute the reviewed destroy plans

Only after reviewing all seven plans and obtaining explicit approval:

```bash
bash gcp-gke/02-scripts/destroy-env.sh amex prod \
  --destroy \
  --plan-dir "$DESTROY_PLAN_DIR"
```

The script verifies the manifest, branch/commit, and checksums for every saved plan before starting. It then displays each saved plan again and requires the operator to type `destroy` for each layer. It applies the exact saved destroy plans in reverse dependency order. If a layer fails or a plan is no longer valid, stop and investigate; do not skip ahead or regenerate plans without reviewing the new plan set.

### 7.5 Verify teardown and preserve bootstrap

After the destroy script completes, inspect the expected resource families:

```bash
gcloud container clusters list
gcloud compute networks list
gcloud artifacts repositories list --location=asia-south1
gcloud filestore instances list --location=asia-south1
gcloud storage buckets describe gs://gcp-tf-state-amex-prod
```

These are project/region inventory commands; they may also show resources not owned by this environment. Confirm the AMEX resources have been removed, investigate any remaining AMEX resources, and confirm the state bucket still exists and is accessible. Do not delete the bucket or run the bootstrap destroy operation.

If teardown was incomplete, stop and resolve the failed layer before starting recreation.

### 7.6 Recreate the environment: plan and apply one layer at a time

After a full teardown, downstream layers may not yet have real dependency outputs. Therefore, do not generate one combined seven-layer deployment plan and assume every plan can use valid upstream outputs. Plan, review, and apply each layer in dependency order so each subsequent layer can consume the real outputs written by the preceding layer.

Keep the same branch and commit used for each plan/apply pair. The scripts require a clean working tree and apply only plans tied to the current commit.

For each layer below, repeat the following procedure, changing `LAYER` to the next layer in the listed order:

1. Create a new empty private plan directory.
2. Generate a plan for only that layer.
3. Inspect the saved plan.
4. If the plan is correct and approved, apply that exact plan using `apply-env.sh`.
5. Confirm the layer completed successfully before moving to the next layer.

Example for the first layer, network:

```bash
LAYER=01-network
PLAN_DIR="$(mktemp -d "/tmp/amex-prod-${LAYER}.XXXXXX")"
chmod 700 "$PLAN_DIR"
echo "Plan directory: $PLAN_DIR"

bash gcp-gke/02-scripts/plan-env.sh amex prod \
  --layer "$LAYER" \
  --plan-dir "$PLAN_DIR"

terragrunt --working-dir \
  "gcp-gke/04-live/clients/amex/prod/$LAYER" \
  run -- show -no-color "$PLAN_DIR/$LAYER.tfplan"
```

After reviewing and approving the network plan, apply it:

```bash
bash gcp-gke/02-scripts/apply-env.sh amex prod \
  --plan-dir "$PLAN_DIR" \
  --approve
```

The apply script displays the saved plan and requires typing `yes`. It verifies the manifest, branch/commit, clean working tree, plan checksum, and dependency order before applying the exact saved plan.

Repeat the same plan → review → apply procedure for these layers, in this exact order:

1. `02-gke`
2. `03-artifact-registry`
3. `04-storage`
4. `05-monitoring`
5. `06-jenkins`
6. `07-applications`

For example, before planning GKE set `LAYER=02-gke` and create a **new empty** `PLAN_DIR`; do not reuse a plan directory from a previous layer. Keep each plan directory until its apply has succeeded and its evidence has been recorded. If a layer fails, stop, diagnose it, and re-plan that layer after the issue is corrected. If any source file is changed, the commit changes, so create fresh plans for the affected layer rather than applying plans from the old commit.

### 7.7 Post-recreation validation

After all seven layers are successfully applied, verify the cluster and workloads:

```bash
gcloud container clusters list
kubectl get nodes
kubectl get pods -A
```

Then validate each layer:

| Layer | Minimum checks |
|---|---|
| Network | Expected VPC, subnets, routes and firewall rules exist |
| GKE | Cluster and node pools are healthy; nodes are Ready |
| Artifact Registry | Expected repository exists and required application images are available |
| Storage | Filestore instance, StorageClasses and expected PVCs are healthy/Bound |
| Monitoring | Prometheus, Grafana, Alertmanager, Loki, Alloy and Tempo are healthy; validate log/metric/trace ingestion |
| Jenkins | Jenkins pods, service, PVC and access path are healthy |
| Applications | Application pods/deployments/services are healthy; expected endpoints respond |

For monitoring-specific checks, use the commands and Grafana/Prometheus/Loki/Tempo validation in Section 5.1. For Jenkins and applications, also verify that their expected load-balancer endpoints and integrations work; a Running pod alone does not prove end-to-end functionality.

### 7.8 Important provider lock-file note

The monitoring provider diagnostic on this review branch pins `hashicorp/helm` to `3.2.0`. A local lock file that still selects `3.3.0` will fail initialization with a provider constraint mismatch. In the monitoring live directory, refresh provider selection before planning when the lock file does not match the configured constraint:

```bash
cd gcp-gke/04-live/clients/amex/prod/05-monitoring
terragrunt run -- init -upgrade
grep -A 4 'registry.terraform.io/hashicorp/helm' .terraform.lock.hcl
```

Confirm the selected version is `3.2.0` before continuing. Treat any lock-file changes as intentional repository changes: do not delete or silently discard them. If the script's clean-working-tree check blocks the workflow, inspect the status and reconcile the lock file with the reviewed branch before generating plans. Do not change chart versions or official Helm repository URLs during this provider A/B test.

### 7.9 Plan directories and evidence

Keep destroy and deployment plan directories private and outside Git. Record the destroy plan directory, each per-layer deployment plan directory, Git commit, identity, project, timestamps, plan review, and typed confirmations. Saved plans and Terraform state can contain sensitive values; retain them only as long as needed and dispose of them securely according to your team's policy.

The lifecycle scripts do not run bootstrap, delete the GCS state bucket, import resources, migrate state, scaffold configuration, or bypass the per-layer approval prompts.

---

## 8. Backend state identity and structural changes

The active root `gcp-gke/04-live/root.hcl` maps directory names to stable logical backend keys. The prefix format is:

```text
gcp-gke/<client>/<environment>/<logical-layer>/terraform.tfstate
```

The logical keys are `bootstrap`, `network`, `gke`, `artifact-registry`, `storage`, `monitoring`, `jenkins`, and `applications`. The monitoring state prefix remains `gcp-gke/amex/prod/monitoring/terraform.tfstate`. Preserve them across folder renames. Before/after backend bucket and prefix values must match for a folder-only refactor.

Follow `gcp-gke/00-documentation/deployment/STATE_LAYOUT_MIGRATION.md` for the required inventory, reference updates, backend-prefix comparison, and baseline-plan equivalence checks. Do not combine structural renames with infrastructure fixes in one unreviewable change.

## 9. Bootstrap bucket ownership

The bootstrap Terraform module declares `google_storage_bucket.tf_state`, but remote backend initialization requires that bucket to exist first. Therefore:

- Provisioning the bucket is a prerequisite, not an automatic deployment-script side effect.
- No orchestration script runs `terragrunt import`.
- If the existing bucket must be brought under Terraform management, assess its ownership and state first, then perform a separately approved import using the correct backend and resource address.
- Never suppress import errors or assume an import succeeded.
- Keep bucket versioning and `prevent_destroy` safeguards enabled.

## 10. Outstanding security review before any real deployment

The D1-D4 code pass does not certify the retained application stack as production-ready. Resolve these findings in a separate security-hardening change before using the configuration outside isolated testing:

- Jenkins admin credentials are still hardcoded in the Jenkins values YAML/JCasC. Replace them with a required secret input sourced from an approved secret manager; rotate any credential that may have been used.
- The Jenkins Docker-in-Docker agent uses privileged mode and an unauthenticated TCP Docker daemon on port 2375. Reassess the build isolation model and remove this exposure where possible.
- Review the project-wide Artifact Registry writer grant and cluster-wide Jenkins deployment RBAC; narrow permissions to the required repository, namespaces, and verbs.
- Review application database/JWT fallback secrets and Terraform-managed Secret Manager secret versions. Terraform state and saved plans may contain secret material; ensure backend access, encryption, retention, and secret injection are appropriate.
- Review ingress hostnames/TLS, image tag pinning, and persistent log/storage settings before any internet-facing or production deployment.

These are follow-up security findings, not changes silently included in this branch. Do not interpret a passing static test or reviewed Terraform plan as approval to deploy them.

## 11. Validation evidence and limitations

Capture:
- Git branch and commit SHA.
- Tool versions and active GCP identity/project.
- Static test output.
- Backend bucket and prefix per live unit.
- Saved plan directory and plan review notes.
- Any real dependency outputs used in the plan.
- Explicit apply/destroy approval and operator decision.

No cloud deployment, Terraform apply/destroy, import, state migration, or remote state mutation is performed by the repository static test suite.
