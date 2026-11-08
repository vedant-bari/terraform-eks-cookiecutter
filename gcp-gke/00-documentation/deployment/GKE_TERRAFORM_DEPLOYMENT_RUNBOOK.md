# GKE Terraform / Terragrunt Deployment Runbook

**Status:** Living operational document  
**Last updated:** 2026-11-04  
**Repository:** `vedant-bari/terraform-eks-cookiecutter`  
**Working branch:** `issue-fixes-GCP-GKE-cluster`  
**Scope:** `gcp-gke/04-live/clients/amex/prod` (retained test configuration)

> [!CAUTION]
> The AMEX configuration is retained as a historical test deployment. The infrastructure previously created from it was deleted. Do not treat this configuration as production-ready. This runbook documents a controlled validation and deployment process; it does not authorize provisioning, importing state, migrating state, or destroying resources. Obtain explicit approval before any state-changing or infrastructure-changing operation.

## 1. Purpose and operating principles

This runbook gives engineers a repeatable sequence for preparing, initializing, validating, planning, and (only after approval) deploying the GKE platform.

Operating rules:

1. Work from the approved branch and confirm the commit before making changes.
2. Verify the active Google Cloud identity and project before every environment operation.
3. Treat the YAML configuration as input that must be reviewed, not as proof that the project, network ranges, quotas, APIs, or resource names are correct.
4. Run static checks and read-only plans before considering deployment.
5. Review every plan. Never use `-auto-approve`.
6. Never run `apply`, `destroy`, `import`, `state mv`, `state rm`, `force-unlock`, or backend migration commands without explicit approval and a documented recovery plan.
7. Never delete a Terraform state object or a GCS bucket as a routine troubleshooting step.
8. Keep secrets out of Git, shell history, logs, and plan artifacts. Use approved secret-management integrations.
9. Execute layers in dependency order. Do not assume numeric directory prefixes alone prove the dependency graph.
10. Record command output, commit SHA, operator, timestamp, and review decision for each validation milestone.

A Terraform plan is not a deployment, but it can refresh/read remote resources and requires valid credentials and API access. Protect saved plan files because they may contain sensitive values.

## 2. Repository layout and live layers

The current GKE repository layout is:

```text
gcp-gke/
├── 00-documentation/
│   ├── architecture/
│   ├── deployment/
│   ├── operations/
│   └── troubleshooting/
├── 01-config/
│   └── clients/amex/prod/
├── 02-scripts/
│   ├── bootstrap/
│   ├── scaffolding/
│   ├── templates/
│   └── validation/
├── 03-modules/
├── 04-live/
│   ├── root.hcl
│   └── clients/amex/prod/
│       ├── 00-bootstrap/
│       ├── 01-network/
│       ├── 02-gke/
│       ├── 03-artifact-registry/
│       ├── 04-storage/
│       ├── 05-monitoring/       # reserved; not in current AMEX sequence
│       ├── 06-jenkins/
│       └── 07-applications/
└── 17-tmp-backup/               # preserved historical backup
```

### Deployment sequence

| Order | Live unit | Purpose | Dependency notes |
|---:|---|---|---|
| 1 | `00-bootstrap` | State bucket foundation | Special handling; see Section 5 |
| 2 | `01-network` | VPC and subnet resources | Foundation for GKE |
| 3 | `02-gke` | GKE cluster | Depends on Network |
| 4 | `03-artifact-registry` | Container image registry | Depends on GKE in current layout |
| 5 | `04-storage` | Storage / Filestore configuration | Depends on GKE and network |
| — | `05-monitoring` | Reserved future layer | Not part of the retained AMEX deployment unless separately approved |
| 6 | `06-jenkins` | Jenkins platform components | Depends on GKE |
| 7 | `07-applications` | Application workloads | Depends on GKE, Artifact Registry, and Jenkins |

The dependency declarations in each `terragrunt.hcl` are authoritative. Re-check them when the repository changes.

## 3. Environment and tool prerequisites

### 3.1 Confirm the working tree and branch

From the repository root:

```bash
git status --short --branch
git branch --show-current
git rev-parse HEAD
```

Use the explicitly approved review/deployment branch for the task; do not assume a fixed branch name. Record the branch and commit SHA in the validation log.

Do not continue with uncommitted changes unless they are understood and intentionally part of the validation. The saved-plan scripts require a clean working tree and bind plans to the branch and commit that produced them.

### 3.2 Confirm tool versions

The versions reported during the current work session were:

- Terragrunt: `1.1.2`
- Terraform: `1.15.8`
- Operating system: Linux amd64

Confirm the versions on the machine actually running the commands:

```bash
terragrunt --version
terraform version
gcloud version
```

If versions differ, check compatibility and command syntax before proceeding. Do not silently upgrade tools during a deployment run.

### 3.3 Verify Google Cloud identity and project

```bash
gcloud auth list
gcloud config get-value account
gcloud config get-value project
gcloud projects describe eks-terraform
```

The active account must be the intended operator identity. The project ID in the retained AMEX YAML is currently `eks-terraform`; this is a repository value and must be independently confirmed with the project owner.

For Terraform's Google provider, verify the intended Application Default Credentials or other approved credential mechanism. A successful `gcloud` command alone does not prove that Terraform is using the same identity.

Do not paste access tokens, service-account keys, private keys, or credential JSON into chat, Git, tickets, or run logs.

### 3.4 Review the environment configuration

Primary file:

`gcp-gke/01-config/clients/amex/prod/infra/prod.yaml`

Review at least:

- Project ID, region, and zone.
- State bucket name.
- VPC and subnet CIDRs; check for overlap with existing networks and planned peering/VPN ranges.
- Pod and Service secondary ranges.
- GKE version, release channel, node machine type, node count, autoscaling bounds, and disk size.
- Filestore tier, capacity, and network attachment.
- Delete protection and all create/enable flags.
- Labels and naming conventions.

Current values include project `eks-terraform`, region `asia-south1`, zone `asia-south1-a`, and state bucket `gcp-tf-state-amex-prod`. These values are not independently certified as correct for a live deployment.

## 4. Remote state design

The shared Terragrunt root is:

`gcp-gke/04-live/root.hcl`

It configures the GCS backend for each live unit. The current prefix convention is:

```text
gcp-gke/<client>/<environment>/<logical-layer>/terraform.tfstate
```

For the retained AMEX test configuration, expected prefixes are:

| Layer | GCS object prefix |
|---|---|
| Bootstrap | `gcp-gke/amex/prod/bootstrap/terraform.tfstate` |
| Network | `gcp-gke/amex/prod/network/terraform.tfstate` |
| GKE | `gcp-gke/amex/prod/gke/terraform.tfstate` |
| Artifact Registry | `gcp-gke/amex/prod/artifact-registry/terraform.tfstate` |
| Storage | `gcp-gke/amex/prod/storage/terraform.tfstate` |
| Monitoring (reserved) | `gcp-gke/amex/prod/monitoring/terraform.tfstate` |
| Jenkins | `gcp-gke/amex/prod/jenkins/terraform.tfstate` |
| Applications | `gcp-gke/amex/prod/applications/terraform.tfstate` |

The logical layer mapping is intentional: renaming a live directory should not silently change the state identity.

**State safety requirements:**

- Use the same approved bucket and prefix for every operation on a given unit.
- Do not share one state object between different units or environments.
- Keep bucket versioning enabled and verify recovery procedures.
- Restrict bucket access to the smallest practical set of operator and automation identities.
- Do not expose state files or saved plans as public artifacts.
- Before state changes, record the current state serial/lineage and take an approved protected backup.
- Any state migration or backend reconfiguration requires a separate reviewed change and recovery plan.

## 5. Bootstrap bucket and backend dependency

### 5.1 Why bootstrap is special

The live root configures the GCS backend using the bucket name from the environment YAML. The bootstrap Terraform module also declares a GCS bucket resource intended to create that same bucket.

This creates a bootstrap ordering problem if the bucket does not exist: Terragrunt must initialize the remote backend before Terraform can manage resources, but the bootstrap module is intended to create the backend bucket.

For this environment, the bucket was subsequently created manually using:

`gcp-gke/02-scripts/bootstrap/01-create-bootstrap-bucket.sh`

with the reported arguments:

```text
Project: eks-terraform
Bucket:  gcp-tf-state-amex-prod
Region:  asia-south1
```

The bucket creation was reported as successful. Its complete configuration and ownership have not yet been independently verified in this runbook.

### 5.2 Verify the bucket before initialization

```bash
gcloud storage buckets describe gs://gcp-tf-state-amex-prod
```

Review and record:

- Bucket name and owning project.
- Location.
- Uniform bucket-level access.
- Versioning status.
- Lifecycle rules.
- Labels.
- IAM access policy, using an appropriately authorized review process.

The bootstrap script currently applies labels including `client=client-b`, which does not match this environment. If the bucket still has that label, correct it only after reviewing the output:

```bash
gcloud storage buckets update gs://gcp-tf-state-amex-prod \
  --update-labels=environment=prod,managed-by=terragrunt,client=amex
```

The script also configures a lifecycle rule that deletes noncurrent object versions when there are five newer versions. This may limit state recovery history. Review the organization's state-retention requirement before accepting that lifecycle policy; do not change it without approval.

The script writes a temporary `lifecycle.json` file in the current working directory and removes it afterward. Check for an existing file before running the script again.

### 5.3 Reconcile Terraform ownership of the pre-created bucket

The bootstrap module declares the bucket as a Terraform-managed resource (currently `google_storage_bucket.tf_state`) and sets `prevent_destroy = true`. Because the bucket was created outside Terraform, it may not yet be present in the bootstrap state.

After backend initialization, inspect the bootstrap state:

```bash
cd gcp-gke/04-live/clients/amex/prod/00-bootstrap
terragrunt state list
```

Possible outcomes:

- **The bucket resource is already in state:** inspect the state and confirm it refers to the expected bucket before planning.
- **The state is empty and the bucket exists:** Terraform does not automatically adopt the existing bucket. A normal plan may propose creating a bucket that already exists. Do not apply that plan.
- **The state contains unexpected resources:** stop and investigate the state lineage, contents, and provenance before doing anything else.

If the bucket is absent from state, the team must choose and review an ownership strategy before the bootstrap plan can be considered actionable. One possible strategy is importing the existing bucket into the bootstrap state, after confirming the exact resource address, provider configuration, bucket identity, and state destination. Import changes Terraform state even though it does not create the bucket; it therefore requires explicit approval and a protected state backup. Another strategy is to separate bucket lifecycle management from this module. Do not choose or execute either strategy implicitly.

**Do not run `apply` on bootstrap while the existing bucket is not correctly represented in state.** Do not delete/recreate the bucket to make the plan appear clean.

## 6. Safe initialization procedure

Initialization configures the backend and downloads providers/modules as needed. It is not an authorization to deploy infrastructure. Confirm the bucket and credentials first.

### 6.1 Initialize bootstrap only

```bash
cd gcp-gke/04-live/clients/amex/prod/00-bootstrap
terragrunt init
```

Do not add `-reconfigure`, `-migrate-state`, or `-force-copy` unless a separately reviewed backend/state procedure explicitly requires it.

If initialization fails:

1. Preserve the full error output.
2. Check active credentials, project, bucket name, bucket IAM permissions, and network access.
3. Confirm the backend prefix from the root configuration.
4. Do not delete `.terragrunt-cache`, local state, or remote state as a first-line fix.
5. Do not switch to a local backend as an improvised workaround.

After successful initialization:

```bash
terragrunt state list
```

Record the result. An empty state is possible for a fresh state object, but it does not mean the pre-created bucket has been adopted by Terraform.

### 6.2 Initialize remaining units

Only after the backend configuration and bootstrap state ownership approach are understood, initialize the other units individually. From the repository root:

```bash
LIVE_BASE="gcp-gke/04-live/clients/amex/prod"

for layer in \
  01-network \
  02-gke \
  03-artifact-registry \
  04-storage \
  06-jenkins \
  07-applications
do
  echo "===== Initializing $layer ====="
  (cd "$LIVE_BASE/$layer" && terragrunt init) || exit 1
done
```

This loop initializes each unit; it does not run plans or apply resources. Stop at the first error and resolve it before continuing. Do not initialize the reserved `05-monitoring` layer as part of this AMEX sequence unless it is explicitly brought into scope.

## 7. Validation gates

Perform validation in stages and preserve the outputs.

### Gate A — Repository and configuration checks

From the repository root:

```bash
git status --short --branch
git rev-parse HEAD
```

Review the YAML files for the selected environment and confirm all referenced paths exist. Use the repository's validation scripts where applicable, but inspect their behavior before execution.

### Gate B — Terragrunt / Terraform validation

Run validation per unit after successful initialization. For example:

```bash
cd gcp-gke/04-live/clients/amex/prod/01-network
terragrunt run -- validate
```

Repeat for each in-scope unit. If the installed Terragrunt release reports a syntax difference, consult that installed version's help rather than guessing or changing tool versions mid-run.

Validation checks configuration and module consistency; it does not prove that cloud resources can be created or that the configuration is operationally correct.

### Gate C — Dependency and output checks

Inspect each unit's `terragrunt.hcl` and verify:

- Every `dependency` path points to the intended live unit.
- Every required dependency output is actually exported by the upstream module.
- Inputs passed to a module are declared by that module.
- Mock outputs, if present, are limited to intended validation/plan use and are not mistaken for real deployed outputs.
- No stale paths from the pre-migration directory layout remain.

A dependency block resolving successfully does not prove that real upstream outputs exist. If a unit requires outputs from a resource that has not been deployed, stop and decide whether the design supports a safe plan without those outputs. Do not create placeholder infrastructure merely to make a plan pass.

### Gate D — Plan each unit

Only plan after validation, dependency checks, and state ownership are understood. Run each plan from its own unit directory, in dependency order:

```bash
cd gcp-gke/04-live/clients/amex/prod/01-network
terragrunt plan
```

Then repeat for `02-gke`, `03-artifact-registry`, `04-storage`, `06-jenkins`, and `07-applications`.

Bootstrap is a separate gate: do not plan it as an actionable deployment until the existing bucket/state ownership issue is resolved. If a diagnostic plan is run before that resolution, label it explicitly as non-actionable and do not apply it.

For every plan, review:

- Planned creates, updates, replacements, and deletions.
- Project, region, zone, names, and labels.
- Network CIDRs and subnet/secondary range changes.
- IAM bindings and service-account permissions.
- GKE version, node pools, autoscaling, disk, and deletion protection.
- Storage capacity, tier, and network association.
- Firewall rules, public endpoints, and ingress exposure.
- Secrets and sensitive values in the plan output.
- Any unexpected data-source or refresh errors.

A plan containing an unexpected delete or replacement is a stop condition. Do not dismiss it as harmless without understanding the resource and state history.

## 8. Approval and deployment procedure

No deployment is authorized by this runbook alone.

Before any apply, the reviewer and operator must agree on:

1. The exact branch and commit SHA.
2. The exact live unit(s) and environment.
3. The reviewed plan output and intended resource changes.
4. The state bucket, prefix, lineage, and backup/recovery plan.
5. The project, region, quota, API enablement, IAM, network, and cost implications.
6. The maintenance window, rollback/recovery approach, and owner.
7. Explicit approval to apply the specific plan.

When approved, use a saved plan workflow where practical:

```bash
terragrunt plan -out=tfplan
terragrunt show tfplan
```

After the plan has been reviewed and the saved plan is the approved artifact, apply that exact plan using the supported command for the installed Terragrunt version. Do not regenerate or substitute a different plan without re-review. Securely handle and remove local plan artifacts according to policy; do not commit them.

After each approved layer deployment:

- Capture the apply result and resulting state summary.
- Verify the deployed resources through the relevant cloud APIs/console.
- Verify expected outputs and service health.
- Proceed to the next dependent layer only after the current layer passes its checks.

## 9. Troubleshooting and stop conditions

| Symptom | Safe response |
|---|---|
| GCS bucket returns 404 | Verify exact bucket name, active account, project, and bucket location. Do not assume the bucket should be recreated. |
| Backend permission denied | Review the operator identity and least-privilege bucket IAM. Do not broaden permissions blindly. |
| Backend init fails | Preserve output; check bucket, prefix, credentials, and backend config. Do not delete state or force migration. |
| Existing bucket conflicts with Terraform create | Stop. Reconcile Terraform ownership through an approved import or module-design change. Do not apply. |
| Dependency output missing | Inspect upstream state and outputs; determine whether the upstream layer has been deployed. Do not fabricate outputs. |
| Plan proposes unexpected replacement/deletion | Stop and inspect state, provider changes, configuration, and resource identity. |
| API disabled / permission error | Confirm required API and project IAM with the project owner. Enabling APIs changes project configuration and requires approval. |
| Provider/module download fails | Check network, registry access, and version constraints. Do not delete lock files or change versions without review. |
| State lock present | Identify the active operation and lock owner. Never force-unlock until stale-lock status is independently established and approved. |

## 10. Current execution record (2026-11-08)

This section is a snapshot of the work in progress. Update it as commands are run and reviewed.

| Item | Status | Notes |
|---|---|---|
| Repository structure migration | Completed | Stage A-C structural work and documented static corrections are on the working branch. |
| Static path/dependency checks | Completed | Prior checks confirmed live module source and dependency paths resolve. |
| Native Terraform/Terragrunt validation | Pending | Earlier static environment did not have native HCL/Terraform validation available. |
| GCP authentication/connectivity | User-reported tested | Reconfirm identity/project in the current shell before continuing. |
| GCS state bucket creation | User-reported completed | Created manually using the bootstrap helper script. |
| GCS bucket configuration review | Pending | Capture and review `gcloud storage buckets describe` output, including labels and lifecycle. |
| Bootstrap backend initialization | Pending | Run only after preflight checks. |
| Bootstrap state inspection | Pending | Determine whether the bucket resource is already represented in state. |
| Bootstrap bucket ownership reconciliation | Pending / approval required | Do not apply while the bucket is out of state. |
| Remaining unit initialization | Pending | Proceed individually after backend/state review. |
| Unit validation and dependency checks | Pending | Run per unit and retain output. |
| Terraform plans | Pending | Run and review per unit; no apply is authorized. |
| Infrastructure deployment | Not authorized | Requires separate explicit approval. |

### Validation log template

Append a dated entry for each execution:

```text
Date/time (timezone):
Operator:
Repository branch:
Commit SHA:
Environment:
Live unit:
Command:
Exit status:
Output / artifact location:
Observed changes or warnings:
Reviewer:
Decision: PASS / FAIL / BLOCKED
Follow-up action:
```

Do not include secrets, access tokens, private keys, or unredacted sensitive plan values in this log.

## 11. Related repository references

- Environment configuration: `gcp-gke/01-config/clients/amex/prod/infra/prod.yaml`
- Terragrunt root/backend: `gcp-gke/04-live/root.hcl`
- Bootstrap live unit: `gcp-gke/04-live/clients/amex/prod/00-bootstrap/terragrunt.hcl`
- Bootstrap module: `gcp-gke/03-modules/01-bootstrap/`
- Bootstrap bucket helper: `gcp-gke/02-scripts/bootstrap/01-create-bootstrap-bucket.sh`
- GKE platform overview: `gcp-gke/README.md`

---

**Change policy:** Keep this runbook synchronized with the actual repository and observed execution results. Mark a step complete only after its command output has been reviewed. Record deviations and decisions rather than silently changing the procedure.

## 12. Saved-plan orchestration (D1/D2 workflow)

The orchestration scripts are deliberately split by responsibility. They do not create or import the remote-state bucket, and they exclude the bootstrap layer from the ordinary deployment and teardown sequences. The GCS backend bucket must already exist and its Terraform ownership must be reconciled separately before the affected bootstrap state is considered deployable.

### 12.1 Generate scaffolding only when explicitly requested

Scaffolding writes Terragrunt files from the YAML configuration and templates. It is no longer part of deployment planning or applying.

From the repository root:

```bash
bash gcp-gke/02-scripts/scaffold-env.sh amex prod --write
git diff -- gcp-gke/04-live/clients/amex/prod
```

Review every generated change. Do not assume the generator output is safe merely because the command completed.

### 12.2 Create saved deployment plans

The plan workflow is read/plan-only: it does not scaffold, import state, create the backend bucket, or apply resources.

```bash
bash gcp-gke/02-scripts/plan-env.sh amex prod
```

The script creates a unique directory under `/tmp` (or `$TMPDIR`) and prints its path. To choose a directory outside the repository:

```bash
bash gcp-gke/02-scripts/plan-env.sh amex prod --plan-dir /secure/path/amex-prod-plans
```

The directory must be empty. It is created with restrictive permissions; saved plan files and the manifest are mode 0600. Treat plans as sensitive artifacts because they can contain secret values. Never commit or publish them.

The manifest records the operation, client, environment, branch, commit, and creation time. The script requires a clean working tree and a named branch. It plans these units in dependency order:

1. `01-network`
2. `02-gke`
3. `03-artifact-registry`
4. `04-storage`
5. `06-jenkins`
6. `07-applications`

The bootstrap unit is intentionally excluded. Do not bypass this exclusion by manually importing the bucket or applying a bootstrap plan without a separately reviewed state-ownership procedure.

Review each saved plan using the matching live unit directory and the installed Terragrunt version's supported show command. A plan is not approved merely because it was generated successfully.

### 12.3 Apply only the reviewed saved plans

Applying requires the same branch and commit that produced the plans, a clean working tree, the plan directory, and an explicit approval flag. The script also requires a typed confirmation for every layer.

```bash
bash gcp-gke/02-scripts/apply-env.sh amex prod \\
  --plan-dir /secure/path/amex-prod-plans \\
  --approve
```

The script initializes each live unit and applies the exact saved plan file. It does not regenerate plans. If the branch/commit differs, a plan is missing, or Terraform detects stale state, stop and generate/review a fresh plan set. Approval is per layer; if a later layer is declined or fails, earlier applied layers are not automatically rolled back.

`deploy-env.sh` remains as a compatibility entry point, but it is plan-only and delegates to `plan-env.sh`. It cannot apply resources.

### 12.4 Destroy is opt-in and uses saved destroy plans

The default destroy command creates destroy plans only:

```bash
bash gcp-gke/02-scripts/destroy-env.sh amex prod
```

It prints the plan directory. Review every destroy plan before proceeding. Actual destruction requires all three of `--destroy`, `--plan-dir`, and `--approve`, plus a typed per-layer confirmation:

```bash
bash gcp-gke/02-scripts/destroy-env.sh amex prod \\
  --destroy \\
  --plan-dir /secure/path/amex-prod-destroy-plans \\
  --approve
```

The destroy workflow applies the saved destroy plans in reverse dependency order. It never regenerates them during destruction. The bootstrap layer and remote-state bucket are excluded intentionally. If the plan set is stale or the branch/commit changed, stop and regenerate/re-review the destroy plans.

### 12.5 Script safety boundaries

- Unknown command-line options are errors; they are not silently ignored.
- Planning and applying do not invoke scaffolding.
- No orchestration script runs `terragrunt import`.
- Applying requires explicit `--approve` and per-layer typed confirmation.
- Destruction is never the default action.
- Saved plans are stored outside the repository and protected with restrictive file permissions.
- The plan/apply scripts require the same branch and commit; do not switch branches or edit configuration between those stages.
- No script performs `terraform apply`, `terragrunt apply`, or destroy automatically as a side effect of planning.
- These scripts have not been executed against GCP as part of this code change. Run shell syntax checks and review the script diff locally before using them.

