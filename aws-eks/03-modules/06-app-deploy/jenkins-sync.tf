# 8. Render each app's single-branch pipeline job XML into a ConfigMap
resource "kubernetes_config_map_v1" "jenkins_job_xml_cm" {
  for_each = local.jenkins_apps

  metadata {
    name      = "jenkins-job-xml-${each.key}"
    namespace = var.jenkins_namespace
  }

  data = {
    "job.xml" = templatefile("${path.module}/templates/job-config.xml.tpl", {
      job_name           = try(each.value.jenkinsPipeline.jobName, "${each.key}-pipeline")
      git_url            = try(each.value.jenkinsPipeline.gitUrl, "")
      branch             = try(each.value.jenkinsPipeline.branch, "")
      github_credentials = try(each.value.jenkinsPipeline.credentials[0].id, "")

      aws_region   = var.region
      cluster_name = var.cluster_name
      ecr_registry = var.ecr_registry_url

      image_repo      = each.value.image.repository
      k8s_namespace   = local.app_namespace[each.key]
      deployment_name = local.app_release[each.key]
      container_name  = local.app_release[each.key]
    })
  }
}

# 9. ConfigMap holding the sync script run by the in-cluster Job
resource "kubernetes_config_map_v1" "jenkins_sync_script" {
  metadata {
    name      = "jenkins-sync-script"
    namespace = var.jenkins_namespace
  }

  data = {
    "sync_jenkins.py" = file("${path.module}/templates/sync_jenkins.py")
  }
}

# RBAC for the sync Job: read only the Jenkins admin secret
resource "kubernetes_service_account_v1" "jenkins_sync_sa" {
  metadata {
    name      = "jenkins-sync-sa"
    namespace = var.jenkins_namespace
  }
}

resource "kubernetes_role_v1" "jenkins_sync_role" {
  metadata {
    name      = "jenkins-sync-secret-reader"
    namespace = var.jenkins_namespace
  }

  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = ["jenkins"]
    verbs          = ["get"]
  }
}

resource "kubernetes_role_binding_v1" "jenkins_sync_role_binding" {
  metadata {
    name      = "jenkins-sync-secret-reader-binding"
    namespace = var.jenkins_namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.jenkins_sync_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.jenkins_sync_sa.metadata[0].name
    namespace = var.jenkins_namespace
  }
}

# 10. In-cluster Job that creates/updates the pipeline through the Jenkins REST
# API and triggers a build. The build pushes the first image and runs
# kubectl set image, so the Job waits for the app Deployment and the deployer
# RBAC to exist (GCP ran it unordered).
resource "kubernetes_job_v1" "sync_jenkins_pipelines" {
  for_each = local.jenkins_apps

  metadata {
    name      = "sync-jenkins-${each.key}-${substr(sha256(kubernetes_config_map_v1.jenkins_job_xml_cm[each.key].data["job.xml"]), 0, 8)}"
    namespace = var.jenkins_namespace
  }

  spec {
    template {
      metadata {
        labels = {
          app = "jenkins-sync"
        }
      }
      spec {
        service_account_name = kubernetes_service_account_v1.jenkins_sync_sa.metadata[0].name
        restart_policy       = "Never"

        container {
          name    = "sync"
          image   = var.jenkins_sync_image
          command = ["python3"]
          args = [
            "/scripts/sync_jenkins.py",
            try(each.value.jenkinsPipeline.jobName, "${each.key}-pipeline"),
            "/config/job.xml"
          ]

          env {
            name  = "JENKINS_URL"
            value = var.jenkins_url
          }

          env {
            name = "JENKINS_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = "jenkins"
                key  = "jenkins-admin-password"
              }
            }
          }

          volume_mount {
            mount_path = "/scripts"
            name       = "script-volume"
          }

          volume_mount {
            mount_path = "/config"
            name       = "xml-volume"
          }
        }

        volume {
          name = "script-volume"
          config_map {
            name = kubernetes_config_map_v1.jenkins_sync_script.metadata[0].name
          }
        }

        volume {
          name = "xml-volume"
          config_map {
            name = kubernetes_config_map_v1.jenkins_job_xml_cm[each.key].metadata[0].name
          }
        }
      }
    }

    backoff_limit = 3
  }

  depends_on = [
    helm_release.app_deployment,
    kubernetes_role_binding_v1.jenkins_deployer_binding,
    kubernetes_config_map_v1.jenkins_job_xml_cm,
    kubernetes_config_map_v1.jenkins_sync_script,
    kubernetes_role_binding_v1.jenkins_sync_role_binding,
    kubernetes_secret_v1.jenkins_app_credentials,
  ]
}
