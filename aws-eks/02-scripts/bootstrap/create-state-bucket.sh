#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
usage() { echo "Usage: bash create-state-bucket.sh <bucket-name> <aws-region>"; }
[[ $# -eq 2 ]] || { usage >&2; exit 2; }
BUCKET=$1; REGION=$2
[[ "$BUCKET" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]] || { echo "Invalid S3 bucket name" >&2; exit 2; }
command -v aws >/dev/null || { echo "AWS CLI is required" >&2; exit 1; }
IDENTITY="$(aws sts get-caller-identity)"
ACCOUNT_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["Account"])' <<< "$IDENTITY")"
echo "AWS account: $ACCOUNT_ID"
echo "Region: $REGION"
echo "Bucket: $BUCKET"
echo "This creates a new remote-state bucket. It does not import or initialize Terraform state."
read -r -p "Create this bucket? Type 'create': " confirm
[[ "$confirm" == create ]] || { echo "Cancelled."; exit 1; }

if [[ "$REGION" == us-east-1 ]]; then
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
    --create-bucket-configuration "LocationConstraint=$REGION"
fi
aws s3api put-bucket-versioning --bucket "$BUCKET" --region "$REGION" \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$BUCKET" --region "$REGION" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "$BUCKET" --region "$REGION" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
POLICY_FILE="$(mktemp)"
trap 'rm -f "$POLICY_FILE"' EXIT
cat > "$POLICY_FILE" <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyInsecureTransport",
    "Effect": "Deny",
    "Principal": "*",
    "Action": "s3:*",
    "Resource": ["arn:aws:s3:::$BUCKET", "arn:aws:s3:::$BUCKET/*"],
    "Condition": {"Bool": {"aws:SecureTransport": "false"}}
  }]
}
POLICY
aws s3api put-bucket-policy --bucket "$BUCKET" --region "$REGION" --policy "file://$POLICY_FILE"
aws s3api get-bucket-versioning --bucket "$BUCKET" --region "$REGION"
aws s3api get-bucket-encryption --bucket "$BUCKET" --region "$REGION"
echo "Bootstrap bucket created and baseline protections configured."
echo "Next: verify bucket ownership and access, then run plan-env.sh. Do not delete this bucket during environment teardown."
