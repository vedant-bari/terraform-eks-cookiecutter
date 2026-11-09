variable "observability_config" {
  description = "Unified Helm values, Grafana credential metadata and chart versions for the observability stack"
  type        = any
}

variable "grafana_admin_username" {
  description = "Grafana administrator username"
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana administrator password; supplied through the operator environment"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.grafana_admin_password) >= 12
    error_message = "Grafana admin password must contain at least 12 characters."
  }
}

variable "cluster_endpoint" {
  description = "GKE Cluster Endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "GKE Cluster CA Certificate"
  type        = string
}
