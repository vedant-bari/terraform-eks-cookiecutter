output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_name" {
  description = "Name tag of the VPC."
  value       = var.vpc_name
}

output "vpc_cidr_block" {
  description = "Primary CIDR of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "azs" {
  description = "Availability zones the subnets are spread across, in subnet order."
  value       = module.vpc.azs
}

output "private_subnet_ids" {
  description = "Private subnet IDs (nodes, pods, EFS mount targets), in azs order."
  value       = module.vpc.private_subnets
}

output "private_subnet_ids_by_az" {
  description = "Map of AZ to private subnet ID, used to pin node groups to specific AZs."
  value       = zipmap(module.vpc.azs, module.vpc.private_subnets)
}

output "public_subnet_ids" {
  description = "Public subnet IDs (internet-facing ALBs, NAT), in azs order."
  value       = module.vpc.public_subnets
}

output "private_route_table_ids" {
  description = "Private route table IDs."
  value       = module.vpc.private_route_table_ids
}

output "public_route_table_ids" {
  description = "Public route table IDs."
  value       = module.vpc.public_route_table_ids
}

output "nat_public_ips" {
  description = "Elastic IPs of the NAT gateway(s): the egress IPs to allowlist on external systems (Git, Docker Hub)."
  value       = module.vpc.nat_public_ips
}

output "flow_logs_bucket_name" {
  description = "S3 bucket receiving VPC flow logs, or null when flow logs are off."
  value       = var.flow_logs_enabled ? aws_s3_bucket.flow_logs[0].bucket : null
}

output "s3_gateway_endpoint_id" {
  description = "ID of the S3 gateway endpoint, or null."
  value       = var.s3_gateway_endpoint ? aws_vpc_endpoint.s3[0].id : null
}

output "interface_endpoint_ids" {
  description = "Map of service suffix to interface endpoint ID (empty when the toggle is off)."
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.id }
}
