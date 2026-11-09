include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/aws-eks/03-modules/02-vpc"
}

inputs = {
  create_vpc             = include.root.locals.config.vpc.create
  name                   = include.root.locals.config.vpc.name
  cidr                   = try(include.root.locals.config.vpc.cidr, "")
  azs                    = try(include.root.locals.config.vpc.azs, [])
  private_subnets        = try(include.root.locals.config.vpc.private_subnets, [])
  public_subnets         = try(include.root.locals.config.vpc.public_subnets, [])
  database_subnets       = try(include.root.locals.config.vpc.database_subnets, [])
  existing_vpc_id        = try(include.root.locals.config.vpc.existing_vpc_id, "")
  existing_private_subnet_ids = try(include.root.locals.config.vpc.existing_private_subnet_ids, [])
  existing_public_subnet_ids  = try(include.root.locals.config.vpc.existing_public_subnet_ids, [])
  enable_nat_gateway     = try(include.root.locals.config.vpc.enable_nat_gateway, true)
  single_nat_gateway     = try(include.root.locals.config.vpc.single_nat_gateway, true)
  enable_dns_hostnames   = try(include.root.locals.config.vpc.enable_dns_hostnames, true)
  enable_dns_support     = try(include.root.locals.config.vpc.enable_dns_support, true)
  map_public_ip_on_launch = try(include.root.locals.config.vpc.map_public_ip_on_launch, false)
  enable_flow_logs       = try(include.root.locals.config.vpc.enable_flow_logs, true)
  flow_logs_retention_days = try(include.root.locals.config.vpc.flow_logs_retention_days, 30)

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${include.root.locals.config.eks.cluster_name}" = "shared"
  }
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${include.root.locals.config.eks.cluster_name}" = "shared"
  }
  tags = include.root.locals.tags
}
