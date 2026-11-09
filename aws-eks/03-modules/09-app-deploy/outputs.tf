output "release_names" {
  description = "Names of the managed application Helm releases."
  value       = keys(helm_release.app)
}
output "release_namespaces" {
  description = "Namespaces for managed application Helm releases."
  value       = { for name, release in helm_release.app : name => release.namespace }
}
