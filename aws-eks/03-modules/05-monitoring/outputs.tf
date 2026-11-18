output "namespace" {
  description = "Namespace holding the observability stack."
  value       = kubernetes_namespace_v1.monitoring.metadata[0].name
}

output "grafana_service" {
  description = "Grafana Service (port-forward: kubectl -n <namespace> port-forward svc/<this> 3000:80)."
  value       = "${try(var.observability_config.monitoring.fullnameOverride, "kube-prometheus-stack")}-grafana"
}

output "loki_push_url" {
  description = "In-cluster Loki push endpoint."
  value       = "http://loki.${local.namespace}.svc.cluster.local:3100/loki/api/v1/push"
}

output "tempo_otlp_endpoints" {
  description = "In-cluster Tempo OTLP endpoints for application traces."
  value = {
    grpc = "tempo.${local.namespace}.svc.cluster.local:4317"
    http = "http://tempo.${local.namespace}.svc.cluster.local:4318"
  }
}
