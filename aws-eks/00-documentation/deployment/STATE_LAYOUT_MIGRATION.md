# AWS EKS Terraform state layout migration

## Why this matters

The legacy Terragrunt root in aws-eks/03-live/root.hcl used a path-relative S3 key:

```text
clients/<client>/<environment>/<legacy-layer>/terraform.tfstate
```

The new active root in aws-eks/04-live/root.hcl uses stable logical keys:

```text
aws-eks/<client>/<environment>/<logical-layer>/terraform.tfstate
```

Changing the backend key without migrating state makes Terraform see an empty state. A plan may then propose creating resources that already exist. Do not apply such a plan.

## Before migrating

1. Freeze all Terraform/Terragrunt runs for the affected client/environment.
2. Confirm the exact state bucket and AWS account from the old environment configuration.
3. Inspect the old generated backend configuration or run a read-only state pull from the old live unit to confirm the actual backend key. Do not guess it from folder names.
4. Confirm S3 bucket versioning is enabled and take an additional state backup.
5. Reconcile the new YAML configuration with the deployed resources before running a plan.
6. Ensure no other operator or pipeline can write to either backend key during migration.

## Layer key mapping

For the legacy folder names used by the original AWS layout, the intended logical mapping is:

| Legacy live layer | New live layer | New logical S3 key segment |
| --- | --- | --- |
| 02-vpc | 01-network | network |
| 03-bastion | 02-bastion | bastion |
| 04-eks | 03-eks | eks |
| 05-ebs-csi | 04-ebs-csi | ebs-csi |
| 06-efs-csi | 05-efs-csi | efs-csi |
| 07-monitoring | 06-monitoring | monitoring |
| 08-logging | 07-logging | logging |

The old and new paths are examples; inspect the actual live directory and backend key for your client/environment before migration. Applications are a new layer and have no legacy state mapping in this table.

## Safe migration procedure

For each layer, one at a time:

1. Record the old bucket, old key, new bucket, and new key.
2. Pull and securely store a state backup from the old Terragrunt working directory.
3. Verify the source object exists and the destination object does not contain an unrelated state.
4. With all writers stopped, copy the exact state object to the new key in the same versioned S3 bucket (or use Terraform's supported backend migration flow after confirming both backend configurations).
5. Initialize the new Terragrunt unit and verify its state list before planning.
6. Run a plan and inspect every proposed action. A migrated state should normally show no replacement/create of the already-existing foundation resources; investigate any unexpected change.
7. Keep the old state object and its S3 versions until the migration has been reviewed and accepted.

Example commands below are intentionally placeholders. Replace them only after confirming the actual old and new key names:

```bash
aws s3api head-object --bucket <state-bucket> --key <old-key>
aws s3 cp s3://<state-bucket>/<old-key> s3://<state-bucket>/<new-key>
```

Do not copy .tflock objects. Ensure no Terraform operation is active during the state copy. The new S3 backend uses native lockfiles; lock files are transient coordination objects, not state.

After copying, initialize the new layer and inspect state:

```bash
terragrunt --working-dir aws-eks/04-live/clients/<client>/<environment>/<new-layer> run -- init
terragrunt --working-dir aws-eks/04-live/clients/<client>/<environment>/<new-layer> run -- state list
terragrunt --working-dir aws-eks/04-live/clients/<client>/<environment>/<new-layer> run -- plan
```

The exact Terragrunt command syntax can vary by installed version; use the version pinned by the project and confirm the generated backend points at the intended key before proceeding.

## Important restrictions

- Do not run old and new stacks concurrently against the same infrastructure.
- Do not delete the old state object immediately after copying.
- Do not use terraform state push unless you have a verified backup and understand lineage/serial handling.
- Do not apply a plan that proposes recreating an existing VPC, EKS cluster, node groups, or storage resources.
- The bootstrap/state bucket itself is never managed or destroyed by the new environment orchestration.
- If you cannot prove the old key, state lineage, and resource ownership, stop and perform a manual state review before any apply.
