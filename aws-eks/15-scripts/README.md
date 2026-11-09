# Legacy AWS EKS scripts

This directory is retained for historical reference only. New workflows live under aws-eks/02-scripts.

- deploy-env.sh is a compatibility wrapper for the plan-only deployment entrypoint.
- destroy-env.sh is a compatibility wrapper for the guarded destroy workflow; it does not destroy the state bucket.
- 01-create-bootstrap-bucket.sh delegates to the hardened bootstrap script.
- deploy-app.sh and destroy-app.sh are legacy application commands. Do not use them for environments managed by the new 04-live tree; use the 08-applications Terragrunt layer instead.
- Other legacy helper scripts may reference the old 12-platform-config and 13-kubernetes-apps layout.

Do not combine these historical paths with the active 01-config / 02-scripts / 03-modules / 04-live workflow. Existing state must be handled using the state migration runbook.
