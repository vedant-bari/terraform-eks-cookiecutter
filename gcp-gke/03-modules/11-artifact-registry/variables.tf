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
  description = "GKE cluster name to retrieve node service account"
}

variable "repository_id" {
  type        = string
  description = "Name/ID of the Artifact Registry repository"
}