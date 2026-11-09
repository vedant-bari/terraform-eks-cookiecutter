variable "observability_config" {
  description = "Unified Helm values, credentials metadata and chart versions for the observability stack"
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

variable "alertmanager_webhook_url" {
  description = "Alertmanager webhook receiver URL; supplied through the operator environment"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^https?://", var.alertmanager_webhook_url))
    error_message = "Alertmanager webhook URL must start with http:// or https://."
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
