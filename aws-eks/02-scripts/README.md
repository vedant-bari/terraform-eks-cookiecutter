# AWS EKS automation scripts

Invoke scripts with bash so the workflow does not depend on executable file-mode bits.

- plan-env.sh creates private saved plans only and supports --layer.
- apply-env.sh validates the manifest, source commit, AWS account, and plan checksums; requires --approve and typed yes per layer.
- deploy-env.sh is a backwards-compatible alias for plan-only mode.
- destroy-env.sh creates destroy plans by default; supports one layer with --layer; applies only with --destroy and typed destroy.
- bootstrap/create-state-bucket.sh creates a versioned, encrypted, public-access-blocked S3 backend bucket. It is a separate prerequisite.
- scaffolding/scaffold_client.py generates the eight standard Terragrunt live units from the shared templates. Existing files are preserved unless --force is supplied.
- templates/ contains the reusable Terragrunt live-unit templates.
- Run read-only checks with bash aws-eks/07-tests/run_tests.sh.

Do not delete the S3 state bucket during environment teardown. Saved plans and Terraform state may contain sensitive values; keep plan directories private and outside Git.
