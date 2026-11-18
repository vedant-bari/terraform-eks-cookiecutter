variable "account_id" {
  description = "AWS account ID that owns the bootstrap resources (used to build ARNs)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "state_bucket_name" {
  description = "Name of the existing S3 bucket that holds Terraform state. 02-scripts/bootstrap/01-create-bootstrap-bucket.sh creates it; this module imports and manages it."
  type        = string
}

variable "force_destroy" {
  description = "Allow Terraform to delete the state bucket even if it contains objects. Keep false."
  type        = bool
  default     = false
}

variable "noncurrent_versions_to_keep" {
  description = "Number of noncurrent state object versions to keep before expiring older ones."
  type        = number
  default     = 5
}

variable "kms_key_arn" {
  description = "Optional customer-managed KMS key ARN for the state bucket. Empty uses SSE-S3 (AES256)."
  type        = string
  default     = ""
}

variable "account_ebs_encryption_by_default" {
  description = "Turn on account-level, region-scoped EBS encryption by default (new volumes only)."
  type        = bool
  default     = true
}

variable "deploy_role_name" {
  description = "Name of the IAM role that Terragrunt assumes for every layer after 00-bootstrap."
  type        = string
}

variable "deploy_role_trusted_principal_arns" {
  description = "IAM principals allowed to assume the deploy role. Empty trusts the account root, i.e. any principal in the account whose own IAM policy allows sts:AssumeRole on it."
  type        = list(string)
  default     = []
}

variable "deploy_role_managed_policy_arns" {
  description = "Managed policies attached to the deploy role."
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}

variable "deploy_role_max_session_duration_seconds" {
  description = "Maximum session duration for the deploy role, in seconds (3600-43200)."
  type        = number
  default     = 3600
}
