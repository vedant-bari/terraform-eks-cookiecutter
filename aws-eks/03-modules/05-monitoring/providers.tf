locals {
  # EKS tokens last 15 minutes and these releases can take 20 minutes each, so
  # every request fetches a fresh token instead of using a static one.
  kube_exec_args = concat(
    ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region, "--output", "json"],
    var.kube_role_arn != "" ? ["--role-arn", var.kube_role_arn] : [],
    var.aws_profile != "" ? ["--profile", var.aws_profile] : [],
  )
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = local.kube_exec_args
  }
}

provider "helm" {
  kubernetes = {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = local.kube_exec_args
    }
  }
}
