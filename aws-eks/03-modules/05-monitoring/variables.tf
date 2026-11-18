variable "observability_config" {
  description = "Unified Helm values, Grafana credential metadata and chart versions for the observability stack (monitoring-and-logging/<env>.yaml)."
  type        = any
}

variable "grafana_admin_username" {
  description = "Grafana administrator username."
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana administrator password; supplied through the operator environment."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.grafana_admin_password) >= 12
    error_message = "Grafana admin password must contain at least 12 characters. Export the variable named in credentials.grafana.password_env."
  }
}

variable "storage_class_name" {
  description = "Block StorageClass created by 04-storage. Every storageClass/storageClassName in observability_config must use it."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name from 02-eks."
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS API endpoint from 02-eks."
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Base64 cluster CA from 02-eks."
  type        = string
}

variable "region" {
  description = "AWS region, passed to aws eks get-token."
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile for aws eks get-token (\"\" = default credential chain)."
  type        = string
  default     = ""
}

variable "kube_role_arn" {
  description = "Role that aws eks get-token assumes (the deploy role). \"\" = caller identity."
  type        = string
  default     = ""
}
