# AWS EKS client/environment scaffolding

Generate the standard Terragrunt live-layer directories from the shared templates:

```bash
python3 aws-eks/02-scripts/scaffolding/scaffold_client.py \
  --client amex \
  --environment dev
```

The script reads the matching file under 01-config, verifies client.name and environment, and creates the eight live-layer Terragrunt files under 04-live/clients/<client>/<environment>.

It is idempotent. Existing files are preserved by default; use --force only when you intend to replace customized live HCL with the shared templates. Use --dry-run to preview operations.

The script does not create AWS resources or the S3 backend bucket. Provision and verify the state bucket separately before running Terragrunt init.
