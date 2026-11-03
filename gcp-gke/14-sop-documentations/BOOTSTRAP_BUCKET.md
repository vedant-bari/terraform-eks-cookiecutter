readme_content = """# GCS Remote State Bucket Setup

## Overview
This document outlines the standard procedure for pre-provisioning a Google Cloud Storage (GCS) bucket to act as a remote state backend for Terragrunt. 

By pre-provisioning the bucket via the Google Cloud CLI, we avoid "Chicken-and-Egg" dependency errors where Terraform attempts to manage the lifecycle of its own storage backend.

## Prerequisites
- Google Cloud SDK (`gcloud`) installed and configured.
- Appropriate IAM permissions (Storage Admin).
- Environment variables set for `PROJECT_ID` and `BUCKET_NAME`.

## Bucket Provisioning Script
Execute the following commands in your terminal to provision the bucket with the required production-grade settings:

```bash
# 1. Create the bucket
gcloud storage buckets create gs://${BUCKET_NAME} \\
  --project=${PROJECT_ID} \\
  --location=asia-south1 \\
  --uniform-bucket-level-access

# 2. Enable Versioning (Crucial for State History)
gcloud storage buckets update gs://${BUCKET_NAME} --versioning

# 3. Add Labels (Cost Tracking/Organization)
gcloud storage buckets update gs://${BUCKET_NAME} \\
  --update-labels=environment=prod,managed-by=terragrunt,client=${CLIENT_NAME}

# 4. Apply Lifecycle Rule (Cleanup old versions)
# Create a local file named lifecycle.json first:
# {
#   "rule": [{
#     "action": {"type": "Delete"},
#     "condition": {"numNewerVersions": 5}
#   }]
# }
gcloud storage buckets update gs://${BUCKET_NAME} --lifecycle-file=lifecycle.json



##import the bucket in the by running in the bootstrap folder eg: 03-live/clients/client-b/prod/01-bootstrap$
terragrunt import google_storage_bucket.tf_state gcp-tf-state-hdfc-bank-dev

terragrunt import google_storage_bucket.tf_state gcp-tf-state-hdfc-bank-prod