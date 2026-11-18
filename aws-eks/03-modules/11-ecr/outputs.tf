output "registry_url" {
  description = "Registry host: <account>.dkr.ecr.<region>.amazonaws.com (GCP: <region>-docker.pkg.dev/<project>)."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.${data.aws_partition.current.dns_suffix}"
}

output "repository_namespace" {
  description = "Namespace prefix of every repository (<client>-<env>)."
  value       = var.repository_namespace
}

output "repository_urls" {
  description = "Map of image name to full repository URL."
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "repository_arns" {
  description = "Map of image name to repository ARN."
  value       = { for k, v in aws_ecr_repository.this : k => v.arn }
}
