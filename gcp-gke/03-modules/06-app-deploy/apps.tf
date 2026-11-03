# 1. Create Google Service Accounts per App
resource "google_service_account" "app_gsa" {
  for_each     = local.apps_with_gsa
  project      = var.project_id
  account_id   = split("@", each.value.serviceAccount.annotations["iam.gke.io/gcp-service-account"])[0]
  display_name = "GSA for ${try(each.value.releaseName, each.key)}"
}

# 2. Bind Workload Identity per App
resource "google_service_account_iam_member" "workload_identity" {
  for_each           = local.apps_with_gsa
  service_account_id = google_service_account.app_gsa[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${try(each.value.namespace.name, each.key)}/${try(each.value.serviceAccount.name, "default")}]"
}

# 3. Create Secrets across all discovered apps
resource "google_secret_manager_secret" "secrets" {
  for_each  = local.secrets_map
  project   = var.project_id
  secret_id = each.value.secret_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "secret_versions" {
  for_each    = local.secrets_map
  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = each.value.value
}

# 4. Grant Secret Access to the respective GSA
resource "google_secret_manager_secret_iam_member" "secret_access" {
  for_each  = local.secrets_map
  project   = var.project_id
  secret_id = google_secret_manager_secret.secrets[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value.gsa_email}"

  depends_on = [
    google_service_account.app_gsa
  ]
}

# 5. Create Kubernetes Namespaces per App
resource "kubernetes_namespace_v1" "app_ns" {
  for_each = local.processed_apps_map

  metadata {
    name = try(each.value.namespace.name, try(each.value.releaseName, each.key))
    labels = {
      "managed-by" = "terragrunt-helm"
    }
  }
}

# 6. Unified Helm Release Deployment for all apps
resource "helm_release" "app_deployment" {
  for_each = local.processed_apps_map

  name             = try(each.value.releaseName, each.key)
  chart            = var.chart_path
  namespace        = try(each.value.namespace.name, try(each.value.releaseName, each.key))
  create_namespace = false
  timeout          = try(each.value.timeout, 300)

  values = [
    yamlencode(each.value)
  ]

  depends_on = [
    kubernetes_namespace_v1.app_ns,
    google_service_account.app_gsa,
    google_service_account_iam_member.workload_identity,
    # google_artifact_registry_repository_iam_member.gar_writer,
    google_secret_manager_secret_version.secret_versions,
    google_secret_manager_secret_iam_member.secret_access
  ]
}