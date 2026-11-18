# ------------------------------------------------------------------------------
# Cluster connection (kubernetes provider, exec auth)
# ------------------------------------------------------------------------------

variable "cluster_name" {
  type        = string
  description = "EKS cluster name from 02-eks."
}

variable "cluster_endpoint" {
  type        = string
  description = "EKS API endpoint from 02-eks."
}

variable "cluster_certificate_authority_data" {
  type        = string
  description = "Base64 cluster CA from 02-eks."
}

variable "region" {
  type        = string
  description = "AWS region, passed to aws eks get-token."
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile for aws eks get-token (\"\" = default credential chain)."
  default     = ""
}

variable "kube_role_arn" {
  type        = string
  description = "Role that aws eks get-token assumes (the deploy role, which has a cluster-admin access entry). \"\" = use the caller's identity."
  default     = ""
}

# ------------------------------------------------------------------------------
# Network
# ------------------------------------------------------------------------------

variable "name_prefix" {
  type        = string
  description = "<client>-<env>, used for resource names."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID from 01-network."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets from 01-network; one EFS mount target is created in each."
}

variable "nfs_client_security_group_ids" {
  type        = list(string)
  description = "Security groups allowed to reach EFS on NFS (2049): the node security group and the cluster primary security group."
}

# ------------------------------------------------------------------------------
# Block storage (GCP standard-rwo)
# ------------------------------------------------------------------------------

variable "block_storage_class_name" {
  type        = string
  description = "Name of the EBS gp3 StorageClass, marked as the cluster default."
  default     = "gp3"
}

variable "block_kms_key_arn" {
  type        = string
  description = "\"\" = the account default EBS key (aws/ebs). Set a CMK ARN to encrypt volumes with it."
  default     = ""
}

# ------------------------------------------------------------------------------
# Shared RWX storage (GCP Filestore class <client>-<env>-rwx)
# ------------------------------------------------------------------------------

variable "rwx_storage_class_name" {
  type        = string
  description = "Name of the EFS StorageClass. Same name as the GCP Filestore class so app values carry over."
}

variable "efs_throughput_mode" {
  type        = string
  description = "elastic (pay per use, recommended), bursting, or provisioned."
  default     = "elastic"

  validation {
    condition     = contains(["elastic", "bursting", "provisioned"], var.efs_throughput_mode)
    error_message = "efs_throughput_mode must be elastic, bursting or provisioned."
  }
}

variable "efs_transition_to_ia" {
  type        = string
  description = "Move files not accessed for this long to Infrequent Access, e.g. AFTER_30_DAYS. \"\" = never."
  default     = ""
}

variable "efs_backup_enabled" {
  type        = bool
  description = "Enable automatic AWS Backup of the file system (Jenkins home, app logs). false matches GCP (Filestore without backups)."
  default     = false
}

variable "efs_uid" {
  type        = number
  description = "POSIX uid enforced by each EFS access point. EFS ignores fsGroup, so this must match the workload user (Jenkins and the generic-app chart run as 1000)."
  default     = 1000
}

variable "efs_gid" {
  type        = number
  description = "POSIX gid enforced by each EFS access point."
  default     = 1000
}

variable "efs_directory_perms" {
  type        = string
  description = "Permissions of each dynamically provisioned directory."
  default     = "700"
}
