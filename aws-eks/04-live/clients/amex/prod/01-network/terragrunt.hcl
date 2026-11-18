include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/aws-eks/03-modules/02-vpc"
}

locals {
  cfg = include.root.locals.config
  vpc = local.cfg.vpc
}

inputs = {
  account_id  = local.cfg.aws.account_id
  region      = local.cfg.aws.region
  name_prefix = local.cfg.name_prefix

  vpc_name = try(local.vpc.name, "") != "" ? local.vpc.name : "${local.cfg.name_prefix}-vpc"
  vpc_cidr = local.vpc.cidr
  azs      = local.vpc.azs

  private_subnet_cidrs = local.vpc.private_subnet_cidrs
  public_subnet_cidrs  = local.vpc.public_subnet_cidrs

  # Class-B toggle; false = GCP parity (one NAT, like the single Cloud NAT).
  nat_gateway_per_az = try(local.vpc.nat_gateway_per_az, false)

  flow_logs_enabled                  = try(local.vpc.flow_logs.enabled, true)
  flow_logs_traffic_type             = try(local.vpc.flow_logs.traffic_type, "ALL")
  flow_logs_max_aggregation_interval = try(local.vpc.flow_logs.max_aggregation_interval, 60)
  flow_logs_retention_days           = try(local.vpc.flow_logs.retention_days, 30)
  flow_logs_force_destroy            = try(local.vpc.flow_logs.force_destroy, true)

  s3_gateway_endpoint = try(local.vpc.s3_gateway_endpoint, true)

  # Class-B toggle; false = GCP parity (no private endpoints).
  interface_endpoints_enabled = try(local.vpc.interface_endpoints.enabled, false)
  interface_endpoint_services = try(local.vpc.interface_endpoints.services, ["ecr.api", "ecr.dkr", "sts", "secretsmanager", "logs"])
}
