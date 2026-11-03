#!/bin/bash

# Exit immediately if a command exits with a non-zero status
# Example usage:
# ./01-create-bootstrap-bucket.sh aws-tf-state-amex-dev asia-south1

set -e

# 1. Validate input arguments
if [ "$#" -ne 2 ]; then
    echo "Error: Missing required arguments."
    echo "Usage: $0 <BUCKET_NAME> <REGION>"
    echo "Example: $0 aws-tf-state-amex-dev asia-south1"
    exit 1
fi

BUCKET_NAME="$1"
REGION="$2"

echo "--------------------------------------------------"
echo "Starting AWS S3 bootstrap bucket provisioning..."
echo "Bucket Name: ${BUCKET_NAME}"
echo "Region     : ${REGION}"
echo "--------------------------------------------------"

# 2. Create the S3 bucket with region constraint handling
echo "[1/4] Creating S3 bucket..."
if [ "${REGION}" == "us-east-1" ]; then
    aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${REGION}"
else
    aws s3api create-bucket \
        --bucket "${BUCKET_NAME}" \
        --region "${REGION}" \
        --create-bucket-configuration LocationConstraint="${REGION}"
fi

# 3. Enable Versioning for state safety
echo "[2/4] Enabling bucket versioning..."
aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled

# 4. Enable Server-Side Encryption (AES256)
echo "[3/4] Enabling default AES256 encryption..."
aws s3api put-bucket-encryption \
    --bucket "${BUCKET_NAME}" \
    --server-side-encryption-rule '{
        "ApplyServerSideEncryptionByDefault": {
            "Algoritm": "AES256",
            "SSEAlgorithm": "AES256"
        }
    }'

# 5. Apply Public Access Blocks
echo "[4/4] Blocking public access..."
aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "--------------------------------------------------"
echo "Success! S3 bucket ${BUCKET_NAME} is fully provisioned."
echo "You can now import the bucket into your Terragrunt state."
echo "--------------------------------------------------"