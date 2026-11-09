# S3 remote-state bucket module

This reusable module is retained for compatibility and carefully reviewed Terraform ownership/import workflows. It is not called by the active 04-live environment lifecycle.

The normal bootstrap path is aws-eks/02-scripts/bootstrap/create-state-bucket.sh. That script creates a versioned, SSE-S3-encrypted, public-access-blocked bucket and a deny-insecure-transport policy before Terragrunt initialization.

Do not apply this module against an existing bucket without importing the bucket and every managed configuration resource into the intended state. The module intentionally uses lifecycle protection to prevent accidental bucket destruction. The backend bucket is excluded from plan-env and destroy-env orchestration.
