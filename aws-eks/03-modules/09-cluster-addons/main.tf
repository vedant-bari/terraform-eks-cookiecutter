# ==============================================================================
# 09-cluster-addons: no GCP module equivalent. GKE has these built in; EKS needs
# them installed with their own IAM:
#   - AWS Load Balancer Controller: Ingress -> ALB, Service type LoadBalancer -> NLB
#   - Cluster Autoscaler: scales the managed node groups between min and max
# Each gets a Pod Identity role from terraform-aws-modules/eks-pod-identity.
#
# The Secrets Store CSI driver + AWS provider (ASCP) is an EKS managed add-on
# (aws-secrets-store-csi-driver-provider) in 04-eks instead of a Helm release.
# ==============================================================================

provider "helm" {
  kubernetes = {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

    # EKS tokens last 15 minutes; fetch one per request.
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = concat(
        ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region, "--output", "json"],
        var.kube_role_arn != "" ? ["--role-arn", var.kube_role_arn] : [],
        var.aws_profile != "" ? ["--profile", var.aws_profile] : [],
      )
    }
  }
}

# ------------------------------------------------------------------------------
# AWS Load Balancer Controller
# ------------------------------------------------------------------------------

module "lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name            = "${var.cluster_name}-aws-lb-controller"
  use_name_prefix = false

  attach_aws_lb_controller_policy = true

  associations = {
    this = {
      cluster_name    = var.cluster_name
      namespace       = var.namespace
      service_account = var.lb_controller.service_account
    }
  }
}

resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lb_controller.chart_version
  namespace  = var.namespace

  # Its webhooks intercept Service and Pod creation cluster-wide; other
  # releases must not be installed until it is Ready.
  wait    = true
  timeout = 600

  values = [yamlencode({
    clusterName  = var.cluster_name
    region       = var.region
    vpcId        = var.vpc_id
    replicaCount = var.lb_controller.replica_count
    serviceAccount = {
      create = true
      name   = var.lb_controller.service_account
    }
    defaultTags         = var.resource_tags
    podDisruptionBudget = { maxUnavailable = 1 }
  })]

  # Credentials must be in place before the controller pods start.
  depends_on = [module.lb_controller_pod_identity]
}

# ------------------------------------------------------------------------------
# Cluster Autoscaler
# ------------------------------------------------------------------------------

module "cluster_autoscaler_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name            = "${var.cluster_name}-cluster-autoscaler"
  use_name_prefix = false

  # Scoped to ASGs tagged for this cluster (managed node groups tag them).
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [var.cluster_name]

  associations = {
    this = {
      cluster_name    = var.cluster_name
      namespace       = var.namespace
      service_account = var.cluster_autoscaler.service_account
    }
  }
}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = var.cluster_autoscaler.chart_version
  namespace  = var.namespace

  wait    = true
  timeout = 600

  values = [yamlencode({
    cloudProvider    = "aws"
    awsRegion        = var.region
    fullnameOverride = "cluster-autoscaler"
    autoDiscovery = {
      clusterName = var.cluster_name
    }
    image = {
      tag = var.cluster_autoscaler.image_tag
    }
    rbac = {
      serviceAccount = {
        create = true
        name   = var.cluster_autoscaler.service_account
      }
    }
    extraArgs = var.cluster_autoscaler.extra_args
  })]

  depends_on = [
    module.cluster_autoscaler_pod_identity,
    helm_release.lb_controller,
  ]
}
