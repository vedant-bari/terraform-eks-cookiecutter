# Legacy bootstrap tree

This directory is retained for existing state inspection and migration only. New state bucket creation uses aws-eks/02-scripts/bootstrap/create-state-bucket.sh. New live environments use aws-eks/04-live.

Do not run the old bootstrap live unit for a bucket that already exists unless its Terraform state ownership has been explicitly verified. See aws-eks/00-documentation/deployment/STATE_LAYOUT_MIGRATION.md.
