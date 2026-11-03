variable "observability_config" {
  description = "Unified map containing configuration for monitoring, loki, and alloy"
  type        = any
}

variable "cluster_endpoint" {
  description = "GKE Cluster Endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "GKE Cluster CA Certificate"
  type        = string
}