# 11. Grant the Jenkins agent service account permission to roll out each app,
# in that app's namespace only. These Roles are all the pipeline needs when
# jenkins.cluster_wide_rbac is false.
resource "kubernetes_role_v1" "jenkins_deployer" {
  for_each = local.processed_apps_map

  metadata {
    name      = "jenkins-deployer-${each.key}"
    namespace = kubernetes_namespace_v1.app_ns[each.key].metadata[0].name
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "deployments/scale", "replicasets"]
    verbs      = ["get", "list", "watch", "update", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log", "services"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "jenkins_deployer_binding" {
  for_each = local.processed_apps_map

  metadata {
    name      = "jenkins-deployer-binding-${each.key}"
    namespace = kubernetes_namespace_v1.app_ns[each.key].metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.jenkins_deployer[each.key].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.jenkins_agent_service_account
    namespace = var.jenkins_namespace
  }
}
