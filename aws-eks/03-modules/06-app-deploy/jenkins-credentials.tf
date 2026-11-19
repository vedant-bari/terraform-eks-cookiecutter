# 7. Provision app-defined credentials as Kubernetes Secrets in the Jenkins
# namespace; kubernetes-credentials-provider exposes them to pipelines.
resource "kubernetes_secret_v1" "jenkins_app_credentials" {
  for_each = local.jenkins_secrets_map

  metadata {
    name      = each.key
    namespace = var.jenkins_namespace
    labels = {
      "jenkins.io/credentials-type"  = each.value.type
      "jenkins.io/credentials-scope" = "global"
    }
    annotations = {
      "jenkins.io/credentials-description" = "Managed via Terraform - ${each.value.id}"
    }
  }

  data = each.value.data
}
