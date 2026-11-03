# Secure Bootstrap Layer Deletion Guide

## Overview
Because the Terragrunt bootstrap layer houses the central remote state backend (`01-bootstrap`), it is heavily protected against accidental deletion by default. 

Production configurations enforce a strict multi-layer defense:
1. **Terraform Lifecycle Guardrail (`prevent_destroy = true`)**: Hard-aborts any attempt to run `terragrunt destroy` on the bucket or core components.
2. **GCS Storage Guardrail (`force_destroy = false`)**: Prevents Terraform or operators from deleting the bucket while it still contains active state files or historical versions.

If you intentionally need to tear down a client's environment (e.g., Client B) from scratch, you must systematically lift these guards.

---

## Prerequisites
- Google Cloud SDK (`gcloud`) installed and configured.
- Appropriate IAM permissions (Storage Admin / Project Editor).
- Terminal access to the live path: `gcp-gke/03-live/clients/client-b/prod/01-bootstrap`.

---

Summary Warning

Always ensure that all downstream child modules (such as 02-vpc, 04-gke, databases, etc.) are destroyed before you delete the 01-bootstrap layer. Destroying the bootstrap layer first will strand child resources, making them unmanaged and difficult to clean up safely.


## Step-by-Step Deletion Procedure

### Step 1: Lift the Terraform `prevent_destroy` Guard
Terraform will block any destruction attempt while `prevent_destroy` is active. 

1. Open **`gcp-gke/02-modules/01-bootstrap/main.tf`**.
2. Locate the `google_storage_bucket.tf_state` resource and **comment out or remove** the `lifecycle` block:

```hcl
resource "google_storage_bucket" "tf_state" {
  name                        = var.state_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false # Remains false for safety

  versioning {
    enabled = true
  }

  # TEMPORARILY COMMENTED OUT FOR DELETION
  # lifecycle {
  #   prevent_destroy = true
  # }
}

Step 2: Manually Empty the Bucket via CLI

Because force_destroy = false is enforced, Terraform cannot automatically delete the bucket if it contains objects. You must explicitly wipe out all state versions and files manually using the gcloud CLI.

Run the following commands in your terminal:
# Define your bucket name variable
export BUCKET_NAME="prod-gcp-tf-state-client-b-prod"

# 1. Delete all current objects and noncurrent versions recursively
gcloud storage rm -r gs://${BUCKET_NAME}/**

# 2. (Optional) If versioning retention holds prevent deletion, remove object holds/metadata if needed, 
# or ensure the recursive command above cleared everything.


Step 3: Execute Terragrunt Destroy

Now that the Terraform guardrail has been lifted and the storage bucket has been manually emptied, Terraform is permitted to clean up the resource references and disable tracking.

    Navigate to your live client bootstrap folder:
    cd gcp-gke/03-live/clients/client-b/prod/01-bootstrap

    Run the destroy command:
    terragrunt destroy

Step 4: Clean Up Local Artifacts & Caches
rm -rf .terragrunt-cache .terraform terraform.tfstate*


