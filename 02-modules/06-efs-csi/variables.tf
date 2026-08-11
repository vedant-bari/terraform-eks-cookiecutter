variable "cluster_name" {
  description = "Name of the EKS cluster where the EFS CSI add-on is installed."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider used for IRSA."
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "EKS OIDC issuer URL used for the EFS CSI service account trust policy."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID used for new EFS mount-target security groups."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs where mount targets are created for a new EFS file system."
  type        = list(string)
}

variable "node_security_group_id" {
  description = "EKS node security group allowed to mount a new EFS file system over NFS."
  type        = string
}

variable "create_efs" {
  description = "Toggle to create a new EFS file system or use an existing one."
  type        = bool
  default     = true
}

variable "existing_efs_file_system_id" {
  description = "ID of an existing EFS file system to use when create_efs is false."
  type        = string
  default     = ""

  validation {
    condition     = var.create_efs || length(trimspace(var.existing_efs_file_system_id)) > 0
    error_message = "existing_efs_file_system_id must be set when create_efs is false."
  }
}

variable "storage_class_name" {
  description = "Name of the Kubernetes StorageClass that dynamically provisions EFS access points."
  type        = string
  default     = "efs-sc"
}

variable "access_point_base_path" {
  description = "Base directory used by dynamically created EFS access points."
  type        = string
  default     = "/dynamic_provisioning"
}

variable "transition_to_ia" {
  description = "EFS lifecycle policy for files that are not accessed."
  type        = string
  default     = "AFTER_30_DAYS"
}

variable "addon_version" {
  description = "Optional pinned AWS EFS CSI add-on version. Null selects the EKS default compatible version."
  type        = string
  default     = null
}

variable "reclaim_policy" {
  description = "Action taken when a PVC using this StorageClass is deleted."
  type        = string
  default     = "Delete"

  validation {
    condition     = contains(["Delete", "Retain"], var.reclaim_policy)
    error_message = "reclaim_policy must be either Delete or Retain."
  }
}

variable "tags" {
  description = "Tags applied to AWS resources."
  type        = map(string)
  default     = {}
}
