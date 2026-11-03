# 7. Automatically provision application-defined credentials as Kubernetes Secrets in Jenkins namespace
resource "kubernetes_secret_v1" "jenkins_app_credentials" {
  for_each = local.jenkins_secrets_map

  metadata {
    name      = each.key
    namespace = "jenkins"
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