output "namespace" {
  description = "Namespace where Loki and Alloy are installed."
  value       = var.namespace
}

output "loki_gateway_url" {
  description = "In-cluster Loki gateway URL used by Grafana and Alloy."
  value       = "http://loki-gateway.${var.namespace}.svc.cluster.local"
}

output "grafana_dashboard_uid" {
  description = "UID of the provisioned Kubernetes Logs dashboard."
  value       = "kubernetes-logs"
}
