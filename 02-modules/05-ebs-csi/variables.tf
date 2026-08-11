variable "cluster_name" {
  description = "Name of the EKS cluster where the EBS CSI add-on is installed."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider used for IRSA."
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "EKS OIDC issuer URL used for the EBS CSI service account trust policy."
  type        = string
}

variable "storage_class_name" {
  description = "Name of the Kubernetes StorageClass that dynamically provisions gp3 EBS volumes."
  type        = string
  default     = "ebs-gp3"
}

variable "create_ebs" {
  description = "Toggle to dynamically provision new EBS volumes or bind an existing EBS volume to a static PV/PVC."
  type        = bool
  default     = true
}

variable "existing_ebs_volume_id" {
  description = "ID of an existing EBS volume to expose through a static PersistentVolume when create_ebs is false."
  type        = string
  default     = ""

  validation {
    condition     = var.create_ebs || length(trimspace(var.existing_ebs_volume_id)) > 0
    error_message = "existing_ebs_volume_id must be set when create_ebs is false."
  }
}

variable "existing_ebs_pv_name" {
  description = "Name of the static PersistentVolume created for an existing EBS volume."
  type        = string
  default     = "existing-ebs-pv"
}

variable "existing_ebs_pvc_name" {
  description = "Name of the PersistentVolumeClaim bound to an existing EBS volume."
  type        = string
  default     = "existing-ebs-pvc"
}

variable "existing_ebs_pvc_namespace" {
  description = "Namespace of the PersistentVolumeClaim bound to an existing EBS volume."
  type        = string
  default     = "default"
}

variable "existing_ebs_fs_type" {
  description = "Filesystem type already present on the existing EBS volume."
  type        = string
  default     = "ext4"
}

variable "addon_version" {
  description = "Optional pinned AWS EBS CSI add-on version. Null selects the EKS default compatible version."
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
