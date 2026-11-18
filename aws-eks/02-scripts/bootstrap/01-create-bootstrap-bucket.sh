#!/usr/bin/env bash
# Create the Terraform state bucket for one client/environment, before the first
# `terragrunt init` (the S3 backend needs the bucket to exist).
#
# Every value comes from aws-eks/01-config/clients/<client>/<env>/infra/<env>.yaml;
# nothing is passed positionally except client and environment. Safe to re-run:
# an existing bucket is left as-is and its settings are re-applied.
#
# Afterwards, apply 00-bootstrap. Its import block adopts this bucket into
# Terraform state and adds the TLS-only bucket policy and the deploy role.
#
# Example: ./01-create-bootstrap-bucket.sh amex prod
set -Eeuo pipefail
umask 077

[[ $# -eq 2 ]] || { echo "Usage: $0 <client> <environment>" >&2; exit 2; }
CLIENT=$1; ENV=$2

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
load_env_config
assert_aws_account

echo "--------------------------------------------------"
echo "Client / env : ${CLIENT} / ${ENV}"
echo "Account      : ${ACCOUNT_ID}"
echo "Region       : ${REGION}"
echo "Profile      : ${PROFILE:-<default credential chain>}"
echo "Bucket       : ${STATE_BUCKET}"
echo "--------------------------------------------------"

if aws "${AWS_ARGS[@]}" s3api head-bucket --bucket "$STATE_BUCKET" >/dev/null 2>&1; then
  echo "[1/5] Bucket already exists; re-applying settings."
else
  echo "[1/5] Creating bucket..."
  if [[ "$REGION" == "us-east-1" ]]; then
    aws "${AWS_ARGS[@]}" s3api create-bucket --bucket "$STATE_BUCKET"
  else
    aws "${AWS_ARGS[@]}" s3api create-bucket --bucket "$STATE_BUCKET" \
      --create-bucket-configuration "LocationConstraint=${REGION}"
  fi
  aws "${AWS_ARGS[@]}" s3api wait bucket-exists --bucket "$STATE_BUCKET"
fi

echo "[2/5] Blocking all public access and enforcing bucket-owner object ownership..."
aws "${AWS_ARGS[@]}" s3api put-public-access-block --bucket "$STATE_BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws "${AWS_ARGS[@]}" s3api put-bucket-ownership-controls --bucket "$STATE_BUCKET" \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'

echo "[3/5] Enabling versioning..."
aws "${AWS_ARGS[@]}" s3api put-bucket-versioning --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled

echo "[4/5] Enabling default encryption (SSE-S3; 00-bootstrap switches to SSE-KMS if kms_key_arn is set)..."
aws "${AWS_ARGS[@]}" s3api put-bucket-encryption --bucket "$STATE_BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "[5/5] Applying tags..."
TAGSET="$(python3 - "$CONFIG_FILE" <<'PY'
import json, sys, yaml
with open(sys.argv[1], encoding="utf-8") as f:
    tags = ((yaml.safe_load(f) or {}).get("aws") or {}).get("tags") or {}
print(json.dumps({"TagSet": [{"Key": str(k), "Value": str(v)} for k, v in tags.items()]}))
PY
)"
aws "${AWS_ARGS[@]}" s3api put-bucket-tagging --bucket "$STATE_BUCKET" --tagging "$TAGSET"

echo "--------------------------------------------------"
echo "Bucket s3://${STATE_BUCKET} is ready."
echo "Next: terragrunt --working-dir aws-eks/04-live/clients/${CLIENT}/${ENV}/00-bootstrap run -- plan"
echo "--------------------------------------------------"
