resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

# 1. Prometheus Stack (Prometheus, Grafana, Alertmanager)
resource "helm_release" "prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  timeout    = 1200
  values = [yamlencode(var.observability_config.monitoring)]
}

# 2. Loki Log Aggregator
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  timeout    = 1200
  values = [yamlencode(var.observability_config.loki)]
}

# 3. Grafana Alloy (Log Collector)
resource "helm_release" "alloy" {
  name       = "alloy"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  timeout    = 1200
  values = [yamlencode(var.observability_config.alloy)]
}