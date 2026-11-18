variable "repository_namespace" {
  type        = string
  description = "Prefix for every repository name (<client>-<env>). Repos are <namespace>/<image>; the Jenkins push role is scoped to <namespace>/*."
}

variable "repositories" {
  type        = list(string)
  description = "Image names (basenames) to create repositories for. ECR has no multi-image repository, so each image gets its own."

  validation {
    condition     = alltrue([for r in var.repositories : can(regex("^[a-z0-9]+(?:[._-][a-z0-9]+)*$", r))])
    error_message = "Repository names must be lowercase alphanumerics separated by '.', '_' or '-'."
  }
}

variable "image_tag_mutability" {
  type        = string
  description = "MUTABLE is required while the pipeline pushes :latest (GCP parity)."
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  type        = bool
  description = "Basic (free) vulnerability scan on every push."
  default     = true
}

variable "force_delete" {
  type        = bool
  description = "Let terraform destroy delete repositories that still hold images (GCP Artifact Registry repos are deleted the same way)."
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "\"\" = AES256 (AWS-owned key). Set a CMK ARN for KMS encryption. Changing it replaces the repositories."
  default     = ""
}

variable "keep_last_images" {
  type        = number
  description = "Lifecycle: keep this many most recent images per repository."
  default     = 30
}

variable "untagged_expire_days" {
  type        = number
  description = "Lifecycle: expire untagged images after this many days."
  default     = 7
}
