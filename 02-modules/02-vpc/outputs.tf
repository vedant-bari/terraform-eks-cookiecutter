output "vpc_id" {
  description = "The ID of the VPC (either created or adopted)"
  # If create_vpc is true, output the new module's ID. Otherwise, output the existing ID.
  value       = var.create_vpc ? module.vpc[0].vpc_id : data.aws_vpc.existing[0].id
}

output "vpc_cidr_block" {
  description = "VPC CIDR Block"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of private subnet IDs for EKS"
  # If create_vpc is true, output the new subnets. Otherwise, output the provided list.
  value       = var.create_vpc ? module.vpc[0].private_subnets : var.existing_private_subnet_ids
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "database_subnets" {
  description = "Database subnet IDs"
  value       = module.vpc.database_subnets
}

output "database_subnet_group" {
  description = "Database subnet group"
  value       = module.vpc.database_subnet_group
}

output "nat_public_ips" {
  description = "NAT Gateway Public IPs"
  value       = module.vpc.nat_public_ips
}

output "azs" {
  description = "Availability Zones"
  value       = module.vpc.azs
}

output "igw_id" {
  description = "Internet Gateway ID"
  value       = module.vpc.igw_id
}

output "default_security_group_id" {
  description = "Default Security Group ID"
  value       = module.vpc.default_security_group_id
}

