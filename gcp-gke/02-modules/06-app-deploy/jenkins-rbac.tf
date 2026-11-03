# 11. Grant Jenkins SA permissions to manage deployments in the app namespace
resource "kubernetes_role_v1" "jenkins_deployer" {
  for_each = local.processed_apps_map

  metadata {
    name      = "jenkins-deployer-${each.key}"
    namespace = try(each.value.namespace.name, try(each.value.releaseName, each.key))
  }

  rule {
    api_groups = ["", "apps"]
    resources  = ["deployments", "deployments/scale"]
    verbs      = ["get", "list", "watch", "update", "patch"]
  }

  depends_on = [
    helm_release.app_deployment
  ]
}

resource "kubernetes_role_binding_v1" "jenkins_deployer_binding" {
  for_each = local.processed_apps_map

  metadata {
    name      = "jenkins-deployer-binding-${each.key}"
    namespace = try(each.value.namespace.name, try(each.value.releaseName, each.key))
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.jenkins_deployer[each.key].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "jenkins-agent"
    namespace = "jenkins"
  }

  depends_on = [
    helm_release.app_deployment,
    kubernetes_role_v1.jenkins_deployer
  ]
} 
