output "network_name" {
  value       = module.vpc.network_name
  description = "The name of the VPC network."
}

output "network_id" {
  value       = module.vpc.network_id
  description = "The ID of the VPC network."
}

output "network_self_link" {
  value       = module.vpc.network_self_link
  description = "The URI/self-link of the VPC network."
}

output "subnet_name" {
  value       = module.vpc.subnets_names[0]
  description = "The name of the created subnetwork."
}

output "subnet_id" {
  value       = module.vpc.subnets_ids[0]
  description = "The ID of the created subnetwork."
}

output "subnet_self_link" {
  value       = module.vpc.subnets_ids[0] # subnets_ids in the official module holds the full self-link URI
  description = "The self-link of the created subnetwork."
}

output "pod_range_name" {
  value       = var.pod_range_name
  description = "The secondary range name designated for GKE pods."
}

output "subnet_region" {
  value       = var.region
  description = "The region of the subnetwork."
}

output "svc_range_name" {
  value       = var.svc_range_name
  description = "The secondary range name designated for GKE services."
}