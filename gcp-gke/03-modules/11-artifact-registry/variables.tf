variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP Region for the repository"
}

variable "cluster_name" {
  type        = string
  description = "GKE cluster name (optional)"
  default     = ""
}

variable "node_service_account" {
  type        = string
  description = "GKE Node Service Account email (optional)"
  default     = ""
}

variable "repository_id" {
  type        = string
  description = "Name/ID of the Artifact Registry repository"
}