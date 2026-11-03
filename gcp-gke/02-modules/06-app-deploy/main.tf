# # gcp-gke/02-modules/06-app-deploy/main.tf

# locals {
#   # Decode JSON and ONLY keep apps where apps.enabled is true (defaults to true if omitted)
#   apps_map = {
#     for k, json_str in var.apps : k => jsondecode(json_str)
#     if try(jsondecode(json_str).apps.enabled, true) == true
#   }

#   apps_with_gsa = {
#     for k, app_vals in local.apps_map : k => app_vals
#     if try(app_vals.serviceAccount.annotations["iam.gke.io/gcp-service-account"], "") != ""
#   }

#   jenkins_apps = {
#     for k, app_vals in local.apps_map : k => app_vals
#     if try(app_vals.jenkinsPipeline.enabled, false) == true
#   }

#   all_secrets = flatten([
#     for app_key, app_vals in local.apps_map : [
#       for secret in try(app_vals.secretManager.enabled, false) ? app_vals.secretManager.secrets : [] : {
#         key       = "${app_key}-${secret.secretId}"
#         secret_id = secret.secretId
#         value     = secret.secretValue
#         gsa_email = try(app_vals.serviceAccount.annotations["iam.gke.io/gcp-service-account"], "")
#       }
#     ]
#   ])
#   secrets_map = { for s in local.all_secrets : s.key => s }

#   # Extract and normalize credentials from either flat fields or a credentials array
#   jenkins_secrets_list = flatten([
#     for app_key, app_vals in local.jenkins_apps : concat(
#       # Support flat GitHub Token field if defined
#       try(app_vals.jenkinsPipeline.githubToken, "") != "" ? [{
#         key  = "${app_key}-${try(app_vals.jenkinsPipeline.githubCredentialsId, "github-vedant-bari")}"
#         id   = try(app_vals.jenkinsPipeline.githubCredentialsId, "github-vedant-bari")
#         type = "secretText"
#         data = { text = app_vals.jenkinsPipeline.githubToken }
#       }] : [],
#       # Support flat DockerHub fields if defined
#       try(app_vals.jenkinsPipeline.dockerhubPassword, "") != "" ? [{
#         key  = "${app_key}-${try(app_vals.jenkinsPipeline.dockerhubCredentialsId, "dockerhub-id")}"
#         id   = try(app_vals.jenkinsPipeline.dockerhubCredentialsId, "dockerhub-id")
#         type = "usernamePassword"
#         data = {
#           username = try(app_vals.jenkinsPipeline.dockerhubUsername, "")
#           password = app_vals.jenkinsPipeline.dockerhubPassword
#         }
#       }] : [],
#       # Support segregated credentials array block
#       [
#         for cred in try(app_vals.jenkinsPipeline.credentials, []) : {
#           key  = "${app_key}-${cred.id}"
#           id   = cred.id
#           type = cred.type
#           data = cred.type == "secretText" ? { text = try(cred.secretValue, "") } : {
#             username = try(cred.username, "")
#             password = try(cred.password, "")
#           }
#         }
#       ]
#     )
#   ])

#   jenkins_secrets_map = { for s in local.jenkins_secrets_list : s.key => s }
# }

# # 1. Create Google Service Accounts per App
# resource "google_service_account" "app_gsa" {
#   for_each     = local.apps_with_gsa
#   project      = var.project_id
#   account_id   = split("@", each.value.serviceAccount.annotations["iam.gke.io/gcp-service-account"])[0]
#   display_name = "GSA for ${try(each.value.releaseName, each.key)}"
# }

# # 2. Bind Workload Identity per App
# resource "google_service_account_iam_member" "workload_identity" {
#   for_each           = local.apps_with_gsa
#   service_account_id = google_service_account.app_gsa[each.key].name
#   role               = "roles/iam.workloadIdentityUser"
#   member             = "serviceAccount:${var.project_id}.svc.id.goog[${try(each.value.namespace.name, each.key)}/${try(each.value.serviceAccount.name, "default")}]"
# }

# # 3. Create Secrets across all discovered apps
# resource "google_secret_manager_secret" "secrets" {
#   for_each  = local.secrets_map
#   project   = var.project_id
#   secret_id = each.value.secret_id

#   replication {
#     auto {}
#   }
# }

# resource "google_secret_manager_secret_version" "secret_versions" {
#   for_each    = local.secrets_map
#   secret      = google_secret_manager_secret.secrets[each.key].id
#   secret_data = each.value.value
# }

# # 4. Grant Secret Access to the respective GSA
# resource "google_secret_manager_secret_iam_member" "secret_access" {
#   for_each  = local.secrets_map
#   project   = var.project_id
#   secret_id = google_secret_manager_secret.secrets[each.key].id
#   role      = "roles/secretmanager.secretAccessor"
#   member    = "serviceAccount:${each.value.gsa_email}"

#   depends_on = [
#     google_service_account.app_gsa
#   ]
# }

# # 5. Create Kubernetes Namespaces per App
# resource "kubernetes_namespace_v1" "app_ns" {
#   for_each = local.apps_map

#   metadata {
#     name = try(each.value.namespace.name, try(each.value.releaseName, each.key))
#     labels = {
#       "managed-by" = "terragrunt-helm"
#     }
#   }
# }

# # 6. Unified Helm Release Deployment for all apps
# resource "helm_release" "app_deployment" {
#   for_each = local.apps_map

#   name             = try(each.value.releaseName, each.key)
#   chart            = var.chart_path
#   namespace        = try(each.value.namespace.name, try(each.value.releaseName, each.key))
#   create_namespace = false
#   timeout          = try(each.value.timeout, 300)

#   values = [
#     yamlencode(each.value)
#   ]

#   depends_on = [
#     kubernetes_namespace_v1.app_ns,
#     google_service_account.app_gsa,
#     google_service_account_iam_member.workload_identity,
#     google_secret_manager_secret_version.secret_versions,
#     google_secret_manager_secret_iam_member.secret_access
#   ]
# }

# # 7. Automatically provision application-defined credentials as Kubernetes Secrets in Jenkins namespace
# resource "kubernetes_secret_v1" "jenkins_app_credentials" {
#   for_each = local.jenkins_secrets_map

#   metadata {
#     name      = lower(replace(each.value.id, "_", "-"))
#     namespace = "jenkins"
#     labels = {
#       "jenkins.io/credentials-type"  = each.value.type
#       "jenkins.io/credentials-scope" = "global"
#     }
#     annotations = {
#       "jenkins.io/credentials-description" = "Managed via Terraform - ${each.value.id}"
#     }
#   }

#   data = each.value.data
# }

# # 8. Render Single Branch Pipeline XML Configuration via ConfigMap for In-Cluster Job
# resource "kubernetes_config_map_v1" "jenkins_job_xml_cm" {
#   for_each = local.jenkins_apps

#   metadata {
#     name      = "jenkins-job-xml-${each.key}"
#     namespace = "jenkins"
#   }

#   data = {
#     "job.xml" = templatefile("${path.module}/templates/job-config.xml.tpl", {
#       job_name             = lookup(lookup(each.value, "jenkinsPipeline", {}), "jobName", "${each.key}-pipeline")
#       git_url              = lookup(lookup(each.value, "jenkinsPipeline", {}), "gitUrl", "")
#       branch               = lookup(lookup(each.value, "jenkinsPipeline", {}), "branch", "main")
#       github_credentials   = lookup(lookup(each.value, "jenkinsPipeline", {}), "githubCredentialsId", "github-vedant-bari")
#       dockerhub_credential = lookup(lookup(each.value, "jenkinsPipeline", {}), "dockerhubCredentialsId", "dockerhub-id")

#       # Injected from GKE and root inputs via variables
#       gcp_project  = var.project_id
#       gcp_region   = var.region
#       cluster_name = var.cluster_name

#       # Automatically extracted from Helm configuration values
#       image_repo      = lookup(lookup(each.value, "image", {}), "repository", "")
#       k8s_namespace   = try(each.value.namespace.name, try(each.value.releaseName, each.key))
#       deployment_name = try(each.value.releaseName, each.key)
#       container_name  = try(each.value.releaseName, each.key)
#     })
#   }
# }

# # 9. ConfigMap for Python Synchronization Script execution inside the cluster
# resource "kubernetes_config_map_v1" "jenkins_sync_script" {
#   metadata {
#     name      = "jenkins-sync-script"
#     namespace = "jenkins"
#   }

#   data = {
#     "sync_jenkins.py" = file("${path.module}/templates/sync_jenkins.py")
#   }
# }

# # RBAC for In-Cluster Sync Job to securely fetch the Jenkins admin secret
# resource "kubernetes_service_account_v1" "jenkins_sync_sa" {
#   metadata {
#     name      = "jenkins-sync-sa"
#     namespace = "jenkins"
#   }
# }

# resource "kubernetes_role_v1" "jenkins_sync_role" {
#   metadata {
#     name      = "jenkins-sync-secret-reader"
#     namespace = "jenkins"
#   }

#   rule {
#     api_groups     = [""]
#     resources      = ["secrets"]
#     resource_names = ["jenkins"]
#     verbs          = ["get"]
#   }
# }

# resource "kubernetes_role_binding_v1" "jenkins_sync_role_binding" {
#   metadata {
#     name      = "jenkins-sync-secret-reader-binding"
#     namespace = "jenkins"
#   }

#   role_ref {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "Role"
#     name      = kubernetes_role_v1.jenkins_sync_role.metadata[0].name
#   }

#   subject {
#     kind      = "ServiceAccount"
#     name      = kubernetes_service_account_v1.jenkins_sync_sa.metadata[0].name
#     namespace = "jenkins"
#   }
# }

# # 10. In-Cluster Kubernetes Job to Register/Update Single-Branch Pipeline securely via Internal DNS
# resource "kubernetes_job_v1" "sync_jenkins_pipelines" {
#   for_each = local.jenkins_apps

#   metadata {
#     name      = "sync-jenkins-${each.key}-${substr(sha256(kubernetes_config_map_v1.jenkins_job_xml_cm[each.key].data["job.xml"]), 0, 8)}"
#     namespace = "jenkins"
#   }

#   spec {
#     template {
#       metadata {
#         labels = {
#           app = "jenkins-sync"
#         }
#       }
#       spec {
#         service_account_name = kubernetes_service_account_v1.jenkins_sync_sa.metadata[0].name
#         restart_policy       = "Never"

#         container {
#           name    = "sync"
#           image   = "python:3.11-slim"
#           command = ["/bin/sh", "-c"]
#           args = [
#             <<-EOT
#             apt-get update && apt-get install -y curl
#             curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
#             chmod +x kubectl
#             mv kubectl /usr/local/bin/
#             python3 /scripts/sync_jenkins.py "${lookup(lookup(each.value, "jenkinsPipeline", {}), "jobName", "${each.key}-pipeline")}" "/config/job.xml"
#             EOT
#           ]

#           env {
#             name  = "JENKINS_URL"
#             value = "http://jenkins.jenkins.svc.cluster.local:8080"
#           }

#           volume_mount {
#             mount_path = "/scripts"
#             name       = "script-volume"
#           }

#           volume_mount {
#             mount_path = "/config"
#             name       = "xml-volume"
#           }
#         }

#         volume {
#           name = "script-volume"
#           config_map {
#             name = kubernetes_config_map_v1.jenkins_sync_script.metadata[0].name
#           }
#         }

#         volume {
#           name = "xml-volume"
#           config_map {
#             name = kubernetes_config_map_v1.jenkins_job_xml_cm[each.key].metadata[0].name
#           }
#         }
#       }
#     }

#     backoff_limit = 3
#   }

#   depends_on = [
#     helm_release.app_deployment,
#     kubernetes_config_map_v1.jenkins_job_xml_cm,
#     kubernetes_config_map_v1.jenkins_sync_script,
#     kubernetes_role_binding_v1.jenkins_sync_role_binding,
#     kubernetes_secret_v1.jenkins_app_credentials
#   ]
# }

# # 11. Grant Jenkins SA permissions to manage deployments in the app namespace
# resource "kubernetes_role_v1" "jenkins_deployer" {
#   for_each = local.apps_map

#   metadata {
#     name      = "jenkins-deployer-${each.key}"
#     namespace = try(each.value.namespace.name, try(each.value.releaseName, each.key))
#   }

#   rule {
#     api_groups = ["", "apps"]
#     resources  = ["deployments", "deployments/scale"]
#     verbs      = ["get", "list", "watch", "update", "patch"]
#   }

#   depends_on = [
#     helm_release.app_deployment
#   ]
# }

# resource "kubernetes_role_binding_v1" "jenkins_deployer_binding" {
#   for_each = local.apps_map

#   metadata {
#     name      = "jenkins-deployer-binding-${each.key}"
#     namespace = try(each.value.namespace.name, try(each.value.releaseName, each.key))
#   }

#   role_ref {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "Role"
#     name      = kubernetes_role_v1.jenkins_deployer[each.key].metadata[0].name
#   }

#   subject {
#     kind      = "ServiceAccount"
#     name      = "default"
#     namespace = "jenkins"
#   }

#   depends_on = [
#     helm_release.app_deployment,
#     kubernetes_role_v1.jenkins_deployer
#   ]
# }