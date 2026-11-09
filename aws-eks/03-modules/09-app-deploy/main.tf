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

resource "helm_release" "app" {
  for_each = var.apps

  name             = each.key
  chart            = var.chart_path
  namespace        = try(each.value.namespace, "default")
  create_namespace = true
  wait             = true
  timeout          = 900
  atomic            = true
  cleanup_on_fail   = true
  values            = [yamlencode(each.value)]
}
