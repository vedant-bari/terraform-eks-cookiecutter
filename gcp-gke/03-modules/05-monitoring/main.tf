# The namespace and its credentials are created as an explicit preflight step.
# This keeps secret material out of Terraform state.
data "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

# Prometheus, Grafana, Alertmanager, kube-state-metrics and node-exporter.
resource "helm_release" "prometheus_stack" {
  name            = "kube-prometheus-stack"
  repository      = "https://prometheus-community.github.io/helm-charts"
  chart           = "kube-prometheus-stack"
  namespace       = data.kubernetes_namespace_v1.monitoring.metadata[0].name
  timeout         = 1200
  wait            = true
  atomic          = true
  cleanup_on_fail = true
  values          = [yamlencode(var.observability_config.monitoring)]
}

# Loki is the in-cluster log store. Keep it internal (ClusterIP) and persist data.
resource "helm_release" "loki" {
  name            = "loki"
  repository      = "https://grafana.github.io/helm-charts"
  chart           = "loki"
  namespace       = data.kubernetes_namespace_v1.monitoring.metadata[0].name
  timeout         = 1200
  wait            = true
  atomic          = true
  cleanup_on_fail = true
  values          = [yamlencode(var.observability_config.loki)]
}

# Grafana Alloy runs as a DaemonSet and collects Kubernetes container logs.
resource "helm_release" "alloy" {
  name            = "alloy"
  repository      = "https://grafana.github.io/helm-charts"
  chart           = "alloy"
  namespace       = data.kubernetes_namespace_v1.monitoring.metadata[0].name
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
  version         = "3.2.1"
  namespace       = data.kubernetes_namespace_v1.monitoring.metadata[0].name
  timeout         = 1200
  wait            = true
  atomic          = true
  cleanup_on_fail = true
  values          = [yamlencode(var.observability_config.tempo)]
}
