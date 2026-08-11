output "namespace" {
  description = "Namespace where the monitoring stack is installed."
  value       = helm_release.monitoring.namespace
}

output "release_name" {
  description = "Helm release name for the monitoring stack."
  value       = helm_release.monitoring.name
}

output "grafana_service_name" {
  description = "Grafana Service name for local port forwarding."
  value       = "${helm_release.monitoring.name}-grafana"
}
