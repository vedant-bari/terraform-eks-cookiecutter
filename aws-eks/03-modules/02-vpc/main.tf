module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"
  count   = var.create_vpc ? 1 : 0

  name = var.name
  cidr = var.cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  create_database_subnet_group       = var.create_database_subnet_group
  create_database_subnet_route_table = var.create_database_subnet_route_table
  database_subnets                   = var.database_subnets

  enable_nat_gateway  = var.enable_nat_gateway
  single_nat_gateway  = var.single_nat_gateway
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  enable_flow_log                              = var.enable_flow_logs
  create_flow_log_cloudwatch_log_group         = var.enable_flow_logs
  create_flow_log_cloudwatch_iam_role          = var.enable_flow_logs
  flow_log_cloudwatch_log_group_retention_in_days = var.flow_logs_retention_days

  public_subnet_tags   = var.public_subnet_tags
  private_subnet_tags  = var.private_subnet_tags
  database_subnet_tags = var.database_subnet_tags
  tags                 = var.tags
  vpc_tags             = var.vpc_tags
  map_public_ip_on_launch = var.map_public_ip_on_launch
}

data "aws_vpc" "existing" {
  count = var.create_vpc ? 0 : 1
  id    = var.existing_vpc_id

  lifecycle {
    postcondition {
      condition     = length(var.existing_private_subnet_ids) > 0
      error_message = "existing_private_subnet_ids must be provided when create_vpc is false."
    }
  }
}
