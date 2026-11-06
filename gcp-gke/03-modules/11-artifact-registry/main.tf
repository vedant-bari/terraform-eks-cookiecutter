data "google_project" "project" {
  project_id = var.project_id
}

locals {
  default_sa           = "${data.google_project.project.number}-compute@developer.gserviceaccount.com"
  node_service_account = (var.node_service_account != null && var.node_service_account != "" && var.node_service_account != "default") ? var.node_service_account : local.default_sa
}

resource "google_artifact_registry_repository" "shared_repo" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  format        = "DOCKER"
  description   = "Central shared Artifact Registry repository for applications"

  lifecycle {
    prevent_destroy = false
  }
}

# Grant GKE Node Service Account Reader Access to pull images
resource "google_artifact_registry_repository_iam_member" "gke_node_reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.shared_repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${local.node_service_account}"
}