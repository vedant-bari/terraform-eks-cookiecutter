output "gcs_bucket_name" {
  description = "The name of the GCS bucket created for Terragrunt state"
  value       = google_storage_bucket.tf_state.name
}