############################################################
# Load Platform Configuration
############################################################

# locals {

#   unique_indentifier = "${var.project_name}-${var.environment}"
#   common_tags = {
#     Project     =var.project_name
#     Environment = var.environment
#     ManagedBy   = "Terraform"
#     Component   = "bootstrap"
#   }
# }


resource "aws_kms_key" "terraform" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = var.enable_key_rotation

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-terraform-kms"

    }
  )
}

resource "aws_kms_alias" "terraform" {
  name          = var.kms_alias
  target_key_id = aws_kms_key.terraform.key_id
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.bucket_name

  tags = merge(
    var.tags,
    {
      Name = var.bucket_name
    }
  )
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform.arn
      sse_algorithm     = "aws:kms"
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_lock" {
  count = var.create_lock_table ? 1 : 0

  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = var.tags
}


# ############################################################
# # Load Platform Configuration
# ############################################################

# locals {

#   unique_indentifier = "${var.project_name}-${var.environment}"
#   common_tags = {
#     Project     =var.project_name
#     Environment = var.environment
#     ManagedBy   = "Terraform"
#     Component   = "bootstrap"
#   }
# }

# ############################################################
# # Current AWS Account Information
# ############################################################

# data "aws_caller_identity" "current" {}

# data "aws_region" "current" {}

# ############################################################
# # KMS Key
# ############################################################

# resource "aws_kms_key" "terraform_state" {

#   description = "KMS key used to encrypt Terraform state"

#   enable_key_rotation = true
  

#   deletion_window_in_days = 30

#   tags = merge(
#     local.common_tags,
#     {
#       Name = "${local.unique_indentifier}-terraform-state-kms"
#     }
#   )
# }

# ############################################################
# # KMS Alias
# ############################################################

# resource "aws_kms_alias" "terraform_state" {

#   name = "alias/${local.unique_indentifier}-terraform-state"

#   target_key_id = aws_kms_key.terraform_state.key_id
# }

# ############################################################
# # Terraform State Bucket
# ############################################################

# resource "aws_s3_bucket" "terraform_state" {

#   bucket = "${local.unique_indentifier}-terraform-state-bucket"

#   tags = merge(
#     local.common_tags,
#     {
#       Name = "${local.unique_indentifier}-terraform-state-bucket"
#     }
#   )
# }

# ############################################################
# # Bucket Versioning
# ############################################################

# resource "aws_s3_bucket_versioning" "terraform_state" {

#   bucket = aws_s3_bucket.terraform_state.id

#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# ############################################################
# # Bucket Ownership Controls
# ############################################################

# resource "aws_s3_bucket_ownership_controls" "terraform_state" {

#   bucket = aws_s3_bucket.terraform_state.id

#   rule {
#     object_ownership = "BucketOwnerEnforced"
#   }
# }

# ############################################################
# # Block Public Access
# ############################################################

# resource "aws_s3_bucket_public_access_block" "terraform_state" {

#   bucket = aws_s3_bucket.terraform_state.id

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# ############################################################
# # Server Side Encryption
# ############################################################

# resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {

#   bucket = aws_s3_bucket.terraform_state.id

#   rule {

#     apply_server_side_encryption_by_default {

#       kms_master_key_id = aws_kms_key.terraform_state.arn

#       sse_algorithm = "aws:kms"
#     }
#   }
# }

# ############################################################
# # Lifecycle Policy
# ############################################################

# resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {

#   bucket = aws_s3_bucket.terraform_state.id

#   rule {

#     id     = "terraform-state-version-retention"
#     status = "Enabled"

#     noncurrent_version_expiration {
#       noncurrent_days = 90
#     }
#   }
# }

# ############################################################
# # DynamoDB Lock Table
# ############################################################

# # resource "aws_dynamodb_table" "terraform_lock" {

# #   name = local.config.backend.lock_table

# #   billing_mode = "PAY_PER_REQUEST"

# #   hash_key = "LockID"

# #   attribute {
# #     name = "LockID"
# #     type = "S"
# #   }

# #   point_in_time_recovery {
# #     enabled = true
# #   }

# #   tags = merge(
# #     local.common_tags,
# #     {
# #       Name = local.config.backend.lock_table
# #     }
# #   )
# # }

# ############################################################
# # Useful Information
# ############################################################

# locals {

#   backend_config = {
#     bucket         = aws_s3_bucket.terraform_state.bucket
#     region         = data.aws_region.current.name
#     dynamodb_table = aws_dynamodb_table.terraform_lock.name
#     kms_key_id     = aws_kms_key.terraform_state.arn
#   }
# }




