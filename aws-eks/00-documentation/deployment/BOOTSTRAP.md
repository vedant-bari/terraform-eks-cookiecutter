# Bootstrap: state bucket and deploy role

Do this once for each client/environment, before any other layer. It needs credentials for the target account that are allowed to create S3 buckets, IAM roles, and set EBS default encryption. An admin SSO profile works.

## 1. Fill in the infra config

Edit `aws-eks/01-config/clients/<client>/<env>/infra/<env>.yaml`:

- `aws.account_id`: the 12-digit target account. The AWS provider refuses to run against any other account (`allowed_account_ids`).
- `aws.region`
- `aws.profile`: the SSO or CLI profile name. Set it to `""` to use the default credential chain.
- `aws.tags.Owner`, `aws.tags.CostCenter`, `budget.*`: replace every `CHANGE_ME`.

The state bucket name is derived as `<client>-<env>-tfstate-<account_id>` unless you set `bootstrap.state_bucket_name`.

## 2. Create the bucket

```bash
aws sso login --profile <profile>
./aws-eks/02-scripts/bootstrap/01-create-bootstrap-bucket.sh <client> <env>
```

The script:
- checks that your credentials belong to `aws.account_id`
- creates the bucket, or leaves an existing one in place
- blocks public access and enforces bucket-owner object ownership
- turns on versioning and SSE-S3 encryption
- applies the tags from the YAML file

It is safe to re-run.

## 3. Apply 00-bootstrap

```bash
terragrunt --working-dir aws-eks/04-live/clients/<client>/<env>/00-bootstrap run -- plan
terragrunt --working-dir aws-eks/04-live/clients/<client>/<env>/00-bootstrap run -- apply
```

The plan should show the following:
- **Import** of `aws_s3_bucket.tf_state`. An `import` block does this, so no manual `terragrunt import` is needed.
- **Create** of the bucket sub-resources: versioning, encryption, lifecycle (keep 5 noncurrent versions), ownership, public-access block, and a TLS-only bucket policy.
- **Create** of `aws_ebs_encryption_by_default`, if enabled.
- **Create** of the deploy role `<client>-<env>-terraform-deploy`. Every later layer assumes this role through the provider that `root.hcl` generates.

00-bootstrap stores its own state in the same bucket, under `aws-eks/<client>/<env>/bootstrap/terraform.tfstate`. The bucket has `prevent_destroy`, and `destroy-env.sh` never touches this layer.

## 4. Deploy the remaining layers

On a fresh environment, use `deploy-env.sh`. It plans each layer, shows the plan, asks you to type `yes`, then applies it, one layer at a time:

```bash
./aws-eks/02-scripts/deploy-env.sh <client> <env>
```

Once the environment exists, use the saved-plan flow instead:

```bash
./aws-eks/02-scripts/plan-env.sh <client> <env> [--layer <layer>]
./aws-eks/02-scripts/apply-env.sh <client> <env> --plan-dir <dir> --approve
```

## Offline validation

To validate without credentials or a bucket, set `AWS_EKS_OFFLINE=true`. This swaps in a throwaway local backend:

```bash
AWS_EKS_OFFLINE=true terragrunt --working-dir aws-eks/04-live/clients/<client>/<env>/<layer> run -- validate
```

Never run `plan` or `apply` in offline mode.
