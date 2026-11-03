data "google_project" "project" {
  project_id = var.project_id
}

data "google_container_cluster" "cluster" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id
}

locals {
  cluster_sa           = try(data.google_container_cluster.cluster.node_config[0].service_account, "")
  node_service_account = (local.cluster_sa == "" || local.cluster_sa == "default") ? "${data.google_project.project.number}-compute@developer.gserviceaccount.com" : local.cluster_sa
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