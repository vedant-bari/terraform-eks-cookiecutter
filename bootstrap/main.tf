############################################################
# Load Platform Configuration
############################################################

locals {

  config = yamldecode(
    file("${path.module}/../platform-config/platform.yaml")
  )

  common_tags = {
    Project     = local.config.project.name
    Environment = local.config.project.environment
    ManagedBy   = "Terraform"
    Component   = "bootstrap"
  }
}

############################################################
# Current AWS Account Information
############################################################

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

############################################################
# KMS Key
############################################################

resource "aws_kms_key" "terraform_state" {

  description = "KMS key used to encrypt Terraform state"

  enable_key_rotation = try(
    local.config.kms.enable_key_rotation,
    true
  )

  deletion_window_in_days = try(
    local.config.kms.deletion_window_in_days,
    30
  )

  tags = merge(
    local.common_tags,
    {
      Name = "${local.config.project.name}-terraform-state-kms"
    }
  )
}

############################################################
# KMS Alias
############################################################

resource "aws_kms_alias" "terraform_state" {

  name = "alias/${local.config.project.name}-terraform-state"

  target_key_id = aws_kms_key.terraform_state.key_id
}

############################################################
# Terraform State Bucket
############################################################

resource "aws_s3_bucket" "terraform_state" {

  bucket = local.config.backend.bucket

  tags = merge(
    local.common_tags,
    {
      Name = local.config.backend.bucket
    }
  )
}

############################################################
# Bucket Versioning
############################################################

resource "aws_s3_bucket_versioning" "terraform_state" {

  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

############################################################
# Bucket Ownership Controls
############################################################

resource "aws_s3_bucket_ownership_controls" "terraform_state" {

  bucket = aws_s3_bucket.terraform_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

############################################################
# Block Public Access
############################################################

resource "aws_s3_bucket_public_access_block" "terraform_state" {

  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

############################################################
# Server Side Encryption
############################################################

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {

  bucket = aws_s3_bucket.terraform_state.id

  rule {

    apply_server_side_encryption_by_default {

      kms_master_key_id = aws_kms_key.terraform_state.arn

      sse_algorithm = "aws:kms"
    }
  }
}

############################################################
# Lifecycle Policy
############################################################

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {

  bucket = aws_s3_bucket.terraform_state.id

  rule {

    id     = "terraform-state-version-retention"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

############################################################
# DynamoDB Lock Table
############################################################

resource "aws_dynamodb_table" "terraform_lock" {

  name = local.config.backend.lock_table

  billing_mode = "PAY_PER_REQUEST"

  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.config.backend.lock_table
    }
  )
}

############################################################
# Useful Information
############################################################

locals {

  backend_config = {
    bucket         = aws_s3_bucket.terraform_state.bucket
    region         = data.aws_region.current.name
    dynamodb_table = aws_dynamodb_table.terraform_lock.name
    kms_key_id     = aws_kms_key.terraform_state.arn
  }
}