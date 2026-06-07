module "vpc" {

  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.project_name}-${var.environment}"

  cidr = var.network.cidr

  azs = var.network.azs

  public_subnets = var.network.public_subnets

  private_subnets = var.network.private_subnets

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = var.network.enable_nat_gateway

  single_nat_gateway = var.network.single_nat_gateway

  one_nat_gateway_per_az = true

  enable_flow_log = var.network.enable_flow_logs

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.common_tags
}