include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_parent_terragrunt_dir()}/../02-modules/02-vpc"
}

inputs = {
  # Original mappings
  create_vpc                  = include.root.locals.config.vpc.create
  cidr                        = include.root.locals.config.vpc.cidr
  existing_vpc_id             = include.root.locals.config.vpc.existing_id
  existing_private_subnet_ids = include.root.locals.config.vpc.existing_private_subnets

  # NEW: Map the variables requested by the AWS VPC module
  name            = include.root.locals.config.vpc.name
  azs             = include.root.locals.config.vpc.azs
  private_subnets = include.root.locals.config.vpc.private_subnets
  public_subnets  = include.root.locals.config.vpc.public_subnets

  # (Optional) Hardcode basic networking toggles here, or add them to the YAML as well
  enable_nat_gateway   = include.root.locals.config.vpc.enable_nat_gateway
  single_nat_gateway   = include.root.locals.config.vpc.single_nat_gateway
  enable_dns_hostnames = include.root.locals.config.vpc.enable_flow_logs
  enable_dns_support   = include.root.locals.config.vpc.enable_vpc_endpoints
}