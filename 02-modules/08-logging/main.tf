data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

resource "helm_release" "loki" {
  name             = "loki"
  namespace        = var.namespace
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  version          = var.loki_chart_version
  create_namespace = false
  wait             = true
  timeout          = 900
  atomic           = true
  cleanup_on_fail  = true

  values = [var.loki_values]
}

resource "helm_release" "alloy" {
  name             = "alloy-logs"
  namespace        = var.namespace
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "alloy"
  version          = var.alloy_chart_version
  create_namespace = false
  wait             = true
  timeout          = 900
  atomic           = true
  cleanup_on_fail  = true

  values     = [var.alloy_values]
  depends_on = [helm_release.loki]
}

# The Grafana sidecars enabled by kube-prometheus-stack discover these resources
# and provision the datasource and dashboard in the existing Grafana instance.
resource "kubernetes_config_map_v1" "loki_datasource" {
  metadata {
    name      = "loki-grafana-datasource"
    namespace = var.namespace
    labels = {
      grafana_datasource = "1"
    }
  }

  data = {
    "loki-datasource.yaml" = yamlencode({
      apiVersion = 1
      datasources = [{
        name      = "Loki"
        type      = "loki"
        uid       = "loki"
        access    = "proxy"
        url       = "http://loki-gateway.${var.namespace}.svc.cluster.local"
        isDefault = false
        editable  = true
      }]
    })
  }

  depends_on = [helm_release.loki]
}

resource "kubernetes_config_map_v1" "loki_dashboard" {
  metadata {
    name      = "loki-grafana-dashboard"
    namespace = var.namespace
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "loki-overview.json" = jsonencode({
      annotations  = { list = [] }
      editable     = true
      graphTooltip = 0
      id           = null
      links        = []
      panels = [{
        datasource  = { type = "loki", uid = "loki" }
        fieldConfig = { defaults = {}, overrides = [] }
        gridPos     = { h = 18, w = 24, x = 0, y = 0 }
        id          = 1
        options = {
          deduplicationStrategy = "none"
          enableLogDetails      = true
          showCommonLabels      = false
          showLabels            = false
          sortOrder             = "Descending"
          wrapLogMessage        = false
        }
        targets = [{
          datasource = { type = "loki", uid = "loki" }
          editorMode = "code"
          expr       = "{namespace=~\"$namespace\"}"
          refId      = "A"
        }]
        title = "Kubernetes logs"
        type  = "logs"
      }]
      refresh       = "10s"
      schemaVersion = 39
      tags          = ["kubernetes", "logs", "loki"]
      templating = {
        list = [{
          current    = { selected = false, text = "All", value = ".*" }
          datasource = { type = "loki", uid = "loki" }
          definition = "label_values(namespace)"
          includeAll = true
          label      = "Namespace"
          name       = "namespace"
          options    = []
          query      = "label_values(namespace)"
          refresh    = 1
          type       = "query"
        }]
      }
      time    = { from = "now-1h", to = "now" }
      title   = "Kubernetes Logs"
      uid     = "kubernetes-logs"
      version = 1
    })
  }

  depends_on = [kubernetes_config_map_v1.loki_datasource]
}
