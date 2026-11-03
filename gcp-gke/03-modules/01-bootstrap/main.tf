# 1. Enable Essential GCP APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "storage.googleapis.com",
    "file.googleapis.com",
    "serviceusage.googleapis.com",
    "secretmanager.googleapis.com",
    "logging.googleapis.com",
    "iap.googleapis.com",
    "iamcredentials.googleapis.com",
    "artifactregistry.googleapis.com"
  ])

  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# 2. GCS Bucket for Terragrunt Remote State
resource "google_storage_bucket" "tf_state" {
  name                        = var.state_bucket_name
  location                    = var.region
  # project                     = var.project_id
  uniform_bucket_level_access = var.uniform_bucket_level_access
  force_destroy               = var.force_destroy

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 5
    }
  }

  # 2. Add the ultimate safeguard block:
  lifecycle {
    prevent_destroy = true
  }

  labels = var.tags  # <--- Uncommented for tracking

  depends_on = [google_project_service.apis]
}