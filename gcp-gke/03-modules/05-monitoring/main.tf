# The module owns the namespace and Grafana bootstrap credentials.
resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_secret_v1" "grafana_admin" {
  metadata {
    name      = var.observability_config.credentials.grafana.secret_name
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  type = "Opaque"
  data = {
    (var.observability_config.credentials.grafana.username_key) = var.grafana_admin_username
    (var.observability_config.credentials.grafana.password_key) = var.grafana_admin_password
  }
}

# Prometheus, Grafana, Alertmanager, kube-state-metrics and node-exporter.
resource "helm_release" "prometheus_stack" {
  name            = "kube-prometheus-stack"
  repository      = "https://prometheus-community.github.io/helm-charts"
  chart           = "kube-prometheus-stack"
  namespace       = kubernetes_namespace_v1.monitoring.metadata[0].name
  timeout         = 1200
  wait            = true
  atomic          = true
  cleanup_on_fail = true
  values          = [yamlencode(var.observability_config.monitoring)]
  depends_on      = [kubernetes_secret_v1.grafana_admin]
}

# Loki is the in-cluster log store. Keep it internal (ClusterIP) and persist data.
resource "helm_release" "loki" {
  name            = "loki"
  repository      = "https://grafana.github.io/helm-charts"
  chart           = "loki"
  namespace       = kubernetes_namespace_v1.monitoring.metadata[0].name
  timeout         = 1200
  wait            = true
  atomic          = true
  cleanup_on_fail = true
  values          = [yamlencode(var.observability_config.loki)]
  depends_on      = [kubernetes_namespace_v1.monitoring]
}

# Grafana Alloy runs as a DaemonSet and collects Kubernetes container logs.
resource "helm_release" "alloy" {
  name            = "alloy"
  repository      = "https://grafana.github.io/helm-charts"
  chart           = "alloy"
  namespace       = kubernetes_namespace_v1.monitoring.metadata[0].name
  timeout         = 1200
  wait            = true
  atomic          = true
  cleanup_on_fail = true
  values          = [yamlencode(var.observability_config.alloy)]
  depends_on      = [helm_release.loki]
}

# Tempo single-binary mode is appropriate for this small GKE test environment.
# Applications export OTLP traces to the internal ClusterIP service.
resource "helm_release" "tempo" {
  name            = "tempo"
  repository      = "https://grafana-community.github.io/helm-charts"
  chart           = "tempo"
  version         = var.observability_config.chart_versions.tempo
  namespace       = kubernetes_namespace_v1.monitoring.metadata[0].name
  timeout         = 1200
  wait            = true
  atomic          = true
  cleanup_on_fail = true
  values          = [yamlencode(var.observability_config.tempo)]
  depends_on      = [helm_release.prometheus_stack]
}
