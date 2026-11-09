output "vpc_id" {
  description = "ID of the created or adopted VPC."
  value       = var.create_vpc ? module.vpc[0].vpc_id : data.aws_vpc.existing[0].id
}
output "vpc_cidr_block" {
  description = "Primary IPv4 CIDR block of the VPC."
  value       = var.create_vpc ? module.vpc[0].vpc_cidr_block : data.aws_vpc.existing[0].cidr_block
}
output "private_subnet_ids" {
  description = "Private subnet IDs for EKS worker nodes."
  value       = var.create_vpc ? module.vpc[0].private_subnets : var.existing_private_subnet_ids
}
output "public_subnet_ids" {
  description = "Public subnet IDs, for example for an optional bastion."
  value       = var.create_vpc ? module.vpc[0].public_subnets : var.existing_public_subnet_ids
}
output "database_subnet_ids" {
  description = "Database subnet IDs."
  value       = var.create_vpc ? module.vpc[0].database_subnets : []
}
output "nat_public_ips" {
  description = "Public IPs allocated to NAT Gateways."
  value       = var.create_vpc ? module.vpc[0].nat_public_ips : []
}
output "availability_zones" {
  description = "Availability Zones used by the VPC."
  value       = var.create_vpc ? module.vpc[0].azs : []
}
output "internet_gateway_id" {
  description = "Internet Gateway ID for a created VPC."
  value       = var.create_vpc ? module.vpc[0].igw_id : null
}
