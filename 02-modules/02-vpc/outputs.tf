output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR Block"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
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