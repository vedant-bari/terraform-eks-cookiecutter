# 8. Render Single Branch Pipeline XML Configuration via ConfigMap for In-Cluster Job

##jenkins

resource "kubernetes_config_map_v1" "jenkins_job_xml_cm" {
  for_each = local.jenkins_apps

  metadata {
    name      = "jenkins-job-xml-${each.key}"
    namespace = "jenkins"
  }

  data = {
    "job.xml" = templatefile("${path.module}/templates/job-config.xml.tpl", {
      job_name             = lookup(lookup(each.value, "jenkinsPipeline", {}), "jobName", "${each.key}-pipeline")
      git_url              = lookup(lookup(each.value, "jenkinsPipeline", {}), "gitUrl", "")
      branch               = lookup(lookup(each.value, "jenkinsPipeline", {}), "branch", "")
      github_credentials = try(lookup(lookup(each.value, "jenkinsPipeline", {}), "credentials", [])[0].id, "")      
      # dockerhub_credential = lookup(lookup(each.value, "jenkinsPipeline", {}), "dockerhubCredentialsId", "")

      gcp_project  = var.project_id
      gcp_region   = var.region
      cluster_name = var.cluster_name

      image_repo      = each.value.image.repository
      k8s_namespace   = try(each.value.namespace.name, try(each.value.releaseName, each.key))
      deployment_name = try(each.value.releaseName, each.key)
      container_name  = try(each.value.releaseName, each.key)
    })
  }
}

# 9. ConfigMap for Python Synchronization Script execution inside the cluster
resource "kubernetes_config_map_v1" "jenkins_sync_script" {
  metadata {
    name      = "jenkins-sync-script"
    namespace = "jenkins"
  }

  data = {
    "sync_jenkins.py" = file("${path.module}/templates/sync_jenkins.py")
  }
}

# RBAC for In-Cluster Sync Job to securely fetch the Jenkins admin secret
resource "kubernetes_service_account_v1" "jenkins_sync_sa" {
  metadata {
    name      = "jenkins-sync-sa"
    namespace = "jenkins"
  }
}

resource "kubernetes_role_v1" "jenkins_sync_role" {
  metadata {
    name      = "jenkins-sync-secret-reader"
    namespace = "jenkins"
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
    namespace = "jenkins"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.jenkins_sync_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.jenkins_sync_sa.metadata[0].name
    namespace = "jenkins"
  }
}

# 10. In-Cluster Kubernetes Job to Register/Update Single-Branch Pipeline securely via Internal DNS
resource "kubernetes_job_v1" "sync_jenkins_pipelines" {
  for_each = local.jenkins_apps

  metadata {
    name      = "sync-jenkins-${each.key}-${substr(sha256(kubernetes_config_map_v1.jenkins_job_xml_cm[each.key].data["job.xml"]), 0, 8)}"
    namespace = "jenkins"
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
          image   = "python:3.11-slim"
          command = ["/bin/sh", "-c"]
          args = [
            <<-EOT
            apt-get update && apt-get install -y curl
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl
            mv kubectl /usr/local/bin/
            python3 /scripts/sync_jenkins.py "${lookup(lookup(each.value, "jenkinsPipeline", {}), "jobName", "${each.key}-pipeline")}" "/config/job.xml"
            EOT
          ]

          env {
            name  = "JENKINS_URL"
            value = "http://jenkins.jenkins.svc.cluster.local:8080"
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
    # helm_release.app_deployment,
    kubernetes_config_map_v1.jenkins_job_xml_cm,
    kubernetes_config_map_v1.jenkins_sync_script,
    kubernetes_role_binding_v1.jenkins_sync_role_binding,
    kubernetes_secret_v1.jenkins_app_credentials
  ]
}