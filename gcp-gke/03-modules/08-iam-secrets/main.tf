# 1. Explicitly Declare the Service Enablement Resource
resource "google_project_service" "secretmanager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# 2. Create Google Service Account (GSA)
resource "google_service_account" "app_gsa" {
  account_id   = var.google_service_account_name
  display_name = "GSA for ${var.kubernetes_service_account_name} via Workload Identity"
  project      = var.project_id
}

# 3. Bind Workload Identity (Connect KSA to GSA)
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.app_gsa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.kubernetes_service_account_name}]"
}

# 4. Create Secrets in GCP Secret Manager
resource "google_secret_manager_secret" "app_secrets" {
  for_each  = { for s in var.secrets : s.secretId => s }
  secret_id = each.value.secretId
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

# 5. Add Secret Versions (Data payload)
resource "google_secret_manager_secret_version" "app_secret_versions" {
  for_each    = { for s in var.secrets : s.secretId => s }
  secret      = google_secret_manager_secret.app_secrets[each.key].id
  secret_data = each.value.secretValue
}

# 6. Grant GSA Least-Privilege Access to the Created Secrets
resource "google_secret_manager_secret_iam_member" "secret_access" {
  for_each  = { for s in var.secrets : s.secretId => s }
  secret_id = google_secret_manager_secret.app_secrets[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_gsa.email}"
}