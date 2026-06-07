output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnets" {
  description = "Public Subnet IDs"
  value       = module.networking.public_subnets
}

output "private_subnets" {
  description = "Private Subnet IDs"
  value       = module.networking.private_subnets
}

output "private_route_tables" {
  description = "Private Route Tables"
  value       = module.networking.private_route_tables
}