module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = var.vpc_module_version

  # VPC Basic Details
  name = var.name
  cidr = var.cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  # Database Subnets
  create_database_subnet_group       = var.create_database_subnet_group
  create_database_subnet_route_table = var.create_database_subnet_route_table
  database_subnets                   = var.database_subnets

  # NAT Gateways
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  # DNS
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  # Tags
  public_subnet_tags   = var.public_subnet_tags
  private_subnet_tags  = var.private_subnet_tags
  database_subnet_tags = var.database_subnet_tags

  tags     = var.tags
  vpc_tags = var.vpc_tags

  map_public_ip_on_launch = var.map_public_ip_on_launch
}