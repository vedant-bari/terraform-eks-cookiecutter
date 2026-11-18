# ------------------------------------------------------------------------------
# Terraform state bucket.
# 02-scripts/bootstrap/01-create-bootstrap-bucket.sh creates the bucket before
# the first `terragrunt init` (the S3 backend needs it). The import block below
# adopts it into this layer's state, replacing the manual `terragrunt import`
# step of the GCP runbook.
# ------------------------------------------------------------------------------
import {
  to = aws_s3_bucket.tf_state
  id = var.state_bucket_name
}

resource "aws_s3_bucket" "tf_state" {
  bucket        = var.state_bucket_name
  force_destroy = var.force_destroy

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == "" ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn == "" ? null : var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != ""
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days           = 1
      newer_noncurrent_versions = var.noncurrent_versions_to_keep
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.tf_state]
}

data "aws_iam_policy_document" "tf_state_tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.tf_state.arn,
      "${aws_s3_bucket.tf_state.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  policy = data.aws_iam_policy_document.tf_state_tls_only.json

  depends_on = [aws_s3_bucket_public_access_block.tf_state]
}

# ------------------------------------------------------------------------------
# Account-level EBS encryption by default (current region only).
# ------------------------------------------------------------------------------
resource "aws_ebs_encryption_by_default" "this" {
  count   = var.account_ebs_encryption_by_default ? 1 : 0
  enabled = true
}

# ------------------------------------------------------------------------------
# Deploy role assumed by Terragrunt for every layer after 00-bootstrap
# (see the generated provider in aws-eks/04-live/root.hcl).
# ------------------------------------------------------------------------------
locals {
  deploy_role_trusted_principals = (
    length(var.deploy_role_trusted_principal_arns) > 0
    ? var.deploy_role_trusted_principal_arns
    : ["arn:aws:iam::${var.account_id}:root"]
  )
}

data "aws_iam_policy_document" "deploy_role_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "AWS"
      identifiers = local.deploy_role_trusted_principals
    }
  }
}

resource "aws_iam_role" "deploy" {
  name                 = var.deploy_role_name
  description          = "Assumed by Terragrunt to deploy the aws-eks platform layers."
  assume_role_policy   = data.aws_iam_policy_document.deploy_role_trust.json
  max_session_duration = var.deploy_role_max_session_duration_seconds
}

resource "aws_iam_role_policy_attachment" "deploy" {
  for_each = toset(var.deploy_role_managed_policy_arns)

  role       = aws_iam_role.deploy.name
  policy_arn = each.value
}
