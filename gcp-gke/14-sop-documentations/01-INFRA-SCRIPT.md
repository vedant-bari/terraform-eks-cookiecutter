Here is the complete documentation packaged into a clean markdown file. You can create the file directly in your repository by running the command below in your terminal:

```bash
cat << 'EOF' > DEPLOYMENT_GUIDE.md
# Multi-Client Infrastructure Deployment Guide

Follow this strict step-by-step procedure to provision a new client environment (e.g., Client C) from scratch while preventing state and resource conflict errors.

---

### Step 1: Define Your Client Configuration
Before running any scripts, ensure your client configuration YAML file is set up with the correct project details, region, and state bucket name (e.g., `gcp-gke/12-platform-config/clients/client-c/infra/prod.yaml`).

Example configuration structure:
```yaml
client:
  name: "client-c"
environment: "prod"

gcp:
  project_id: "eks-terraform"
  region: "asia-south1"

bootstrap:
  state_bucket_name: "prod-gcp-tf-state-client-c-prod"
  uniform_bucket_level_access: true

```

---

### Step 2: Generate the Infrastructure Layout

Run your Python scaffolding script, passing your client's YAML configuration path. This automatically builds the correct directory hierarchy for the client:

```bash
python3 gcp-gke/scripts/scaffold_client.py gcp-gke/12-platform-config/clients/client-c/infra/prod.yaml

```

---

### Step 3: Create the Bootstrap GCS State Bucket

Before Terragrunt can manage remote state, the target GCS bucket must exist in your Google Cloud project. Use the provided shell script to provision the bucket directly:

```bash
./create-bootstrap-bucket.sh eks-terraform prod-gcp-tf-state-client-c-prod asia-south1

```

*(Parameters: `PROJECT_ID`, `BUCKET_NAME`, `REGION`)*

---

### Step 4: Initialize and Import the Bucket into Terraform State

Navigate into the bootstrap directory, initialize Terragrunt, and import the existing bucket to prevent `409 AlreadyExists` conflict errors:

```bash
cd gcp-gke/03-live/clients/client-c/prod/01-bootstrap

terragrunt init

terragrunt import google_storage_bucket.tf_state prod-gcp-tf-state-client-c-prod

```

---

### Step 5: Plan and Apply the Bootstrap Layer

While staying inside the `01-bootstrap` folder, run your plan and apply to establish the remote state backend:

```bash
# Verify synchronization
terragrunt plan

# Apply bootstrap layer
terragrunt apply

```

---

### Step 6: Deploy Downstream Layers via `run-all`

Once the bootstrap layer is successfully applied and state is active, navigate out of the bootstrap folder back to the environment root directory (`prod/`) and run the automated execution command for all remaining layers:

```bash
# Navigate out to the client environment root
cd ../

# Execute sequential deployment for VPC, GKE, Bastion, and Storage
terragrunt run-all apply

```

EOF

```

Running this block in your workspace root will immediately generate the `DEPLOYMENT_GUIDE.md` file with all current instructions.

```