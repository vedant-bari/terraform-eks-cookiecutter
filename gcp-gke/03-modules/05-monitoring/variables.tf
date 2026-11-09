variable "observability_config" {
  description = "Unified Helm values for Prometheus/Grafana/Alertmanager, Loki, Alloy, Tempo and chart versions"
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