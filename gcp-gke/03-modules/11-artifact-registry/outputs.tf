output "repository_id" {
  value       = google_artifact_registry_repository.shared_repo.repository_id
  description = "The repository ID"
}

output "repository_name" {
  value       = google_artifact_registry_repository.shared_repo.name
  description = "The fully qualified resource name of the repository"
}

output "repository_url" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.shared_repo.repository_id}"
  description = "The base Docker registry URL"
}