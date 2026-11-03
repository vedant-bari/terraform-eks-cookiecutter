output "cluster_name" {
  value       = module.gke.name
  description = "The name of the GKE cluster."
}

output "cluster_endpoint" {
  value       = module.gke.endpoint
  description = "The IP address of the cluster master endpoint."
  sensitive   = true
}

output "cluster_ca_certificate" {
  value       = module.gke.ca_certificate
  description = "Public certificate authority data for the cluster."
  sensitive   = true
}