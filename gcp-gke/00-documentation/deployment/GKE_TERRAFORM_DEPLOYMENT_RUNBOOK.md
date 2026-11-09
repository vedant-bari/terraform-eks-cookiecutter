# GKE Terraform / Terragrunt Deployment Runbook

**Status:** Living operational document  
**Last updated:** 2026-11-08  
**Repository:** `vedant-bari/terraform-eks-cookiecutter`  
**Review branch:** `review/d1-d2-d3-d4-gke-hardening` (review only; do not merge without approval)  
**Scope:** `gcp-gke/04-live/clients/amex/prod` (retained test configuration)

> [!CAUTION]
> AMEX is retained historical test configuration. Its earlier infrastructure was deleted. Do not treat it as production-ready. This runbook does not authorize provisioning, state import/migration, or destruction. Obtain explicit approval before any infrastructure- or state-changing operation.

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
5. `05-monitoring` — Prometheus, Grafana, Alertmanager, Loki, Alloy and Tempo.
6. `06-jenkins`
7. `07-applications`

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
- Alertmanager with workload alert rules and a webhook receiver.
- Loki single-binary storage and Grafana Alloy DaemonSet for Kubernetes pod/event logs.
- Tempo single-binary mode with OTLP gRPC/HTTP receivers for application traces.

This is a small-cluster/test configuration: one replica for each stateful component, local PVC-backed Loki/Tempo storage and seven-day retention. It is not an HA or long-term archival design.

Create the namespace and Kubernetes secrets before planning. This is an explicit cluster preflight and keeps credentials out of Terraform state:

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

read -rsp "Grafana admin password: " GRAFANA_PASSWORD; echo
kubectl create secret generic grafana-admin-credentials -n monitoring \\
  --from-literal=admin-user=admin \\
  --from-literal=admin-password="$GRAFANA_PASSWORD" \\
  --dry-run=client -o yaml | kubectl apply -f -
unset GRAFANA_PASSWORD

read -rsp "Alertmanager webhook URL: " ALERT_WEBHOOK_URL; echo
kubectl create secret generic alertmanager-webhook -n monitoring \\
  --from-literal=webhook_url="$ALERT_WEBHOOK_URL" \\
  --dry-run=client -o yaml | kubectl apply -f -
unset ALERT_WEBHOOK_URL
```

Use a receiver URL supported by your notification service. Do not commit credentials or paste them into Terraform variables. The monitoring module reads the existing namespace and secrets; it does not manage their secret values.

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

Review the saved plan for only the four Helm releases and expected namespace data lookup. Investigate unexpected replacements, public load balancers/ingress, IAM changes, or unrelated infrastructure changes. Apply only after explicit approval:

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

Open `http://localhost:3000` and sign in using the credentials stored in `grafana-admin-credentials`. Confirm Prometheus, Loki and Tempo data sources are healthy. Check Prometheus Alerts for the configured crash-loop and unavailable-replica rules; send a test alert to validate the webhook receiver.

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

## 7. Destruction (exceptional, separate approval)

Default behavior only creates destroy plans and never destroys resources:

```bash
bash gcp-gke/02-scripts/destroy-env.sh amex prod
```

Review each saved destroy plan. Only with explicit separate approval may the operator apply them:

```bash
bash gcp-gke/02-scripts/destroy-env.sh amex prod --destroy --plan-dir <reviewed-destroy-plan-directory>
```

The script requires a destroy-plan manifest, matching branch/commit/environment, and a per-layer typed confirmation. Bootstrap/state bucket is excluded. Never destroy a state bucket as part of an ordinary environment teardown.

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
