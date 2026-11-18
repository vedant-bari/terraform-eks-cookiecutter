# ==============================================================================
# 10-jenkins: port of gcp-gke/03-modules/10-jenkins.
#
# GCP -> AWS:
#   - Google service account + Workload Identity + project-wide AR writer
#     -> IAM role + EKS Pod Identity association, ECR push scoped to <client>-<env>/*
#   - KSA annotation iam.gke.io/gcp-service-account -> none (Pod Identity binds by namespace/SA)
#   - dockerhub_* variables (unused on GCP) dropped
# Namespace, RBAC and the Helm release are otherwise unchanged.
# ==============================================================================

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

resource "kubernetes_namespace_v1" "jenkins" {
  metadata {
    name = var.namespace
  }
}

# ------------------------------------------------------------------------------
# 1-3. IAM for the CI/CD agents (GCP: jenkins-agent-gsa + Workload Identity)
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "agent_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "agent_ecr" {
  # Registry-wide by API design; returns a token, grants nothing on its own.
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPushPullOwnRepos"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_repository_namespace}/*",
    ]
  }
}

resource "aws_iam_role" "jenkins_agent" {
  name               = "${var.cluster_name}-jenkins-agent"
  description        = "Pod Identity role for ${var.namespace}/${var.agent_service_account}: push to ECR ${var.ecr_repository_namespace}/*"
  assume_role_policy = data.aws_iam_policy_document.agent_trust.json
}

resource "aws_iam_role_policy" "jenkins_agent_ecr" {
  name   = "ecr-push"
  role   = aws_iam_role.jenkins_agent.id
  policy = data.aws_iam_policy_document.agent_ecr.json
}

resource "aws_eks_pod_identity_association" "jenkins_agent" {
  cluster_name    = var.cluster_name
  namespace       = kubernetes_namespace_v1.jenkins.metadata[0].name
  service_account = var.agent_service_account
  role_arn        = aws_iam_role.jenkins_agent.arn
}

# ------------------------------------------------------------------------------
# 4. Kubernetes service account for the agents (no identity annotation needed)
# ------------------------------------------------------------------------------

resource "kubernetes_service_account_v1" "jenkins_agent_sa" {
  metadata {
    name      = var.agent_service_account
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
  }
}

# ------------------------------------------------------------------------------
# 5-6. RBAC: Jenkins controller reads secrets in its own namespace
# (kubernetes-credentials-provider)
# ------------------------------------------------------------------------------

resource "kubernetes_role_v1" "jenkins_secret_reader" {
  metadata {
    name      = "jenkins-secret-reader"
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "jenkins_secret_reader_binding" {
  metadata {
    name      = "jenkins-secret-reader-binding"
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.jenkins_secret_reader.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "jenkins" # Service account created by the official Jenkins Helm chart
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
  }
}

# ------------------------------------------------------------------------------
# 7. Jenkins Helm release
# ------------------------------------------------------------------------------

resource "helm_release" "jenkins" {
  name             = "jenkins"
  repository       = "https://charts.jenkins.io"
  chart            = "jenkins"
  namespace        = kubernetes_namespace_v1.jenkins.metadata[0].name
  create_namespace = true
  version          = var.chart_version
  timeout          = 1200

  values = [
    templatefile(var.yaml_path, {
      cluster_endpoint       = var.cluster_endpoint
      cluster_ca_certificate = var.cluster_certificate_authority_data
      storage_class          = var.storage_class
      access_mode            = var.access_mode
      aws_region             = var.region
    })
  ]

  depends_on = [
    kubernetes_role_binding_v1.jenkins_secret_reader_binding,
    kubernetes_service_account_v1.jenkins_agent_sa,
    aws_eks_pod_identity_association.jenkins_agent,
  ]
}

# ------------------------------------------------------------------------------
# 8-9. Cluster-wide deploy RBAC for the agents (GCP parity; class-B toggle)
# ------------------------------------------------------------------------------

resource "kubernetes_cluster_role_v1" "jenkins_agent_deployer" {
  count = var.cluster_wide_rbac ? 1 : 0

  metadata {
    name = "jenkins-agent-deployer"
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "deployments/scale", "replicasets", "statefulsets", "daemonsets"]
    verbs      = ["get", "list", "watch", "update", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log", "services", "configmaps"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "jenkins_agent_deployer_binding" {
  count = var.cluster_wide_rbac ? 1 : 0

  metadata {
    name = "jenkins-agent-deployer-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.jenkins_agent_deployer[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.jenkins_agent_sa.metadata[0].name
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
  }
}
