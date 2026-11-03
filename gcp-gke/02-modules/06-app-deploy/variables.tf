# variable "project_id" {
#   type = string
# }

# variable "release_name" {
#   type = string
# }

# variable "chart_path" {
#   type = string
# }

# variable "namespace" {
#   type = string
# }

# variable "timeout" {
#   type    = number
#   default = 600
# }

# # variable "app_values" {
# #   type = any
# # }

# variable "cluster_endpoint" {
#   type        = string
#   description = "The GKE cluster endpoint"
# }

# variable "cluster_ca_certificate" {
#   type        = string
#   description = "The GKE cluster CA certificate"
# }

# variable "apps" {
#   type        = list(any)
#   description = "List of auto-discovered applications with their decoded values dictionaries"
# }



variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "cluster_endpoint" {
  type        = string
  description = "GKE Cluster Endpoint"
}

variable "cluster_ca_certificate" {
  type        = string
  description = "GKE Cluster CA Certificate"
}

variable "chart_path" {
  type        = string
  description = "Local filesystem path to the generic Helm chart"
}

variable "apps" {
  type        = map(string)
  description = "Map of app name to JSON-encoded values string"
}

variable "region" {
  type        = string
  description = "Target GCP region for the deployment"
}

variable "cluster_name" {
  type        = string
  description = "Target GKE cluster name"
}