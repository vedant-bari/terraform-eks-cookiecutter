# Keep the two we already fixed!
output "vpc_id" {
  description = "The ID of the VPC"
  value       = var.create_vpc ? one(module.vpc[*].vpc_id) : one(data.aws_vpc.existing[*].id)
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = var.create_vpc ? try(module.vpc[0].private_subnets, []) : var.existing_private_subnet_ids
}

# --- UPDATE THE ONES BELOW ---

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = try(module.vpc[0].vpc_cidr_block, null)
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = try(module.vpc[0].public_subnets, [])
}

output "database_subnets" {
  description = "List of IDs of database subnets"
  value       = try(module.vpc[0].database_subnets, [])
}

output "database_subnet_group" {
  description = "ID of database subnet group"
  value       = try(module.vpc[0].database_subnet_group, null)
}

output "nat_public_ips" {
  description = "List of public Elastic IPs created for AWS NAT Gateway"
  value       = try(module.vpc[0].nat_public_ips, [])
}

output "azs" {
  description = "A list of availability zones specified as argument to this module"
  value       = try(module.vpc[0].azs, [])
}

output "igw_id" {
  description = "The ID of the Internet Gateway"
  value       = try(module.vpc[0].igw_id, null)
}

output "default_security_group_id" {
  description = "The ID of the security group created by default on VPC creation"
  value       = try(module.vpc[0].default_security_group_id, null)
}