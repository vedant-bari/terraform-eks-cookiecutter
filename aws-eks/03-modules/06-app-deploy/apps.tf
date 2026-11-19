# ==============================================================================
# 06-app-deploy: port of gcp-gke/03-modules/06-app-deploy.
#
# GCP -> AWS:
#   - Google service account + Workload Identity  -> IAM role + EKS Pod Identity association
#   - Secret Manager secret + secretAccessor      -> Secrets Manager secret + GetSecretValue on it
#   - Artifact Registry image path                -> ECR repository URL (03-ecr)
# Fixes the GCP first-deploy failure: releases do not wait for pods to become
# Ready, because the image only exists after the Jenkins job (jenkins-sync.tf)
# has built and pushed it.
# ==============================================================================

# 1. IAM role per app (GCP: Google service account)
data "aws_iam_policy_document" "app_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  for_each = local.apps_with_identity

  name               = "${var.cluster_name}-app-${local.app_release[each.key]}"
  description        = "Pod Identity role for ${local.app_namespace[each.key]}/${each.value.serviceAccount.name}"
  assume_role_policy = data.aws_iam_policy_document.app_trust.json

  lifecycle {
    precondition {
      condition     = length("${var.cluster_name}-app-${local.app_release[each.key]}") <= 64
      error_message = "IAM role name for ${each.key} exceeds 64 characters; shorten releaseName."
    }
  }
}

# 2. Bind the role to the app's Kubernetes service account (GCP: workloadIdentityUser)
resource "aws_eks_pod_identity_association" "app" {
  for_each = local.apps_with_identity

  cluster_name    = var.cluster_name
  namespace       = kubernetes_namespace_v1.app_ns[each.key].metadata[0].name
  service_account = each.value.serviceAccount.name
  role_arn        = aws_iam_role.app[each.key].arn
}

# 3. Create secrets across all discovered apps
resource "aws_secretsmanager_secret" "secrets" {
  for_each = local.secrets_map

  name                    = each.value.name
  description             = "Managed by 06-app-deploy for app ${each.value.app}"
  recovery_window_in_days = var.secret_recovery_window_in_days
  kms_key_id              = var.secrets_kms_key_arn == "" ? null : var.secrets_kms_key_arn

  lifecycle {
    precondition {
      condition     = each.value.has_sa
      error_message = "App ${each.value.app} enables secretsManager but sets no serviceAccount.name; secrets are read through the service account's Pod Identity role."
    }
  }
}

resource "aws_secretsmanager_secret_version" "secret_versions" {
  for_each = local.secrets_map

  secret_id     = aws_secretsmanager_secret.secrets[each.key].id
  secret_string = each.value.value
}

# 4. Grant each app read access to its own secrets only (GCP: secretAccessor per secret)
data "aws_iam_policy_document" "app_secrets" {
  for_each = {
    for k, v in local.apps_with_identity : k => [
      for s in values(local.secrets_map) : aws_secretsmanager_secret.secrets[s.key].arn if s.app == k
    ]
    if try(v.secretsManager.enabled, false)
  }

  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = each.value
  }

  dynamic "statement" {
    for_each = var.secrets_kms_key_arn == "" ? [] : [var.secrets_kms_key_arn]
    content {
      actions   = ["kms:Decrypt"]
      resources = [statement.value]
    }
  }
}

resource "aws_iam_role_policy" "app_secrets" {
  for_each = data.aws_iam_policy_document.app_secrets

  name   = "read-own-secrets"
  role   = aws_iam_role.app[each.key].id
  policy = each.value.json
}

# 5. Create Kubernetes Namespaces per App
resource "kubernetes_namespace_v1" "app_ns" {
  for_each = local.processed_apps_map

  metadata {
    name = local.app_namespace[each.key]
    labels = {
      "managed-by" = "terragrunt-helm"
    }
  }
}

# 6. Unified Helm Release Deployment for all apps
resource "helm_release" "app_deployment" {
  for_each = local.processed_apps_map

  name             = local.app_release[each.key]
  chart            = var.chart_path
  namespace        = kubernetes_namespace_v1.app_ns[each.key].metadata[0].name
  create_namespace = false
  timeout          = try(each.value.timeout, 300)

  # First deploy: the ECR repository is empty until the Jenkins job pushes the
  # image, so pods sit in ImagePullBackOff until then. Do not block on them.
  wait = false

  values = [
    yamlencode(local.helm_values[each.key])
  ]

  lifecycle {
    precondition {
      condition     = !try(each.value.ecr.enabled, false) || contains(var.ecr_repository_names, basename(local.apps_map[each.key].image.repository))
      error_message = "App ${each.key} uses ecr.enabled but 03-ecr has no repository for ${basename(local.apps_map[each.key].image.repository)}. Apply 03-ecr first."
    }
  }

  depends_on = [
    aws_eks_pod_identity_association.app,
    aws_secretsmanager_secret_version.secret_versions,
    aws_iam_role_policy.app_secrets,
  ]
}
