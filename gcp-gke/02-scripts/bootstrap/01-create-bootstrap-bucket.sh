#!/bin/bash

# Exit immediately if a command exits with a non-zero status
##sample example
# ./create-bootstrap-bucket.sh your-actual-project-id prod-gcp-tf-state-client-b-prod asia-south1
# ./create-bootstrap-bucket.sh  prod-gcp-tf-state-client-b-prod asia-south1
# ./create-bootstrap-bucket.sh  eks-terraform gcp-tf-state-hdfc-bank-prod asia-south1
# ./create-bootstrap-bucket.sh eks-terraform gcp-tf-state-hdfc-bank-dev asia-south1




set -e

# 1. Validate input arguments
if [ "$#" -ne 3 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <PROJECT_ID> <BUCKET_NAME> <REGION>"
    echo "Example: $0 my-gcp-project-123 prod-gcp-tf-state-client-b-prod asia-south1"
    exit 1
fi

PROJECT_ID="$1"
BUCKET_NAME="$2"
REGION="$3"

echo "--------------------------------------------------"
echo "Starting bootstrap bucket provisioning..."
echo "Project ID : ${PROJECT_ID}"
echo "Bucket Name: ${BUCKET_NAME}"
echo "Region     : ${REGION}"
echo "--------------------------------------------------"

# 2. Create the GCS bucket with Uniform Bucket-Level Access
echo "[1/4] Creating GCS bucket..."
gcloud storage buckets create gs://${BUCKET_NAME} \
  --project=${PROJECT_ID} \
  --location=${REGION} \
  --uniform-bucket-level-access

# 3. Enable Versioning for state safety
echo "[2/4] Enabling bucket versioning..."
gcloud storage buckets update gs://${BUCKET_NAME} --versioning

# 4. Attach operational labels
echo "[3/4] Applying tags and labels..."
gcloud storage buckets update gs://${BUCKET_NAME} \
  --update-labels=environment=prod,managed-by=terragrunt,client=client-b

# 5. Create temporary lifecycle configuration and apply it
echo "[4/4] Setting up retention and lifecycle rules..."
cat <<EOF > lifecycle.json
{
  "rule": [{
    "action": {"type": "Delete"},
    "condition": {"numNewerVersions": 5}
  }]
}
EOF

gcloud storage buckets update gs://${BUCKET_NAME} --lifecycle-file=lifecycle.json

# Clean up the local temporary file
rm lifecycle.json

echo "--------------------------------------------------"
echo "Success! Bucket gs://${BUCKET_NAME} is fully provisioned."
echo "You can now initialize your Terragrunt bootstrap directory."
echo "--------------------------------------------------"