include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/aws-eks/03-modules/04-eks"
}

dependency "vpc" {
  config_path = "../01-network"
  mock_outputs = {
    vpc_id = "vpc-00000000000000000"
    private_subnet_ids = ["subnet-00000000000000000"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate"]
}

inputs = {
  cluster_name = include.root.locals.config.eks.cluster_name
  cluster_version = include.root.locals.config.eks.cluster_version
  vpc_id = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  cluster_addons = include.root.locals.config.eks.cluster_addons
  node_groups = include.root.locals.config.eks.node_groups
  cluster_enabled_log_types = include.root.locals.config.eks.cluster_enabled_log_types
  create_cloudwatch_log_group = include.root.locals.config.eks.create_cloudwatch_log_group
  cluster_endpoint_private_access = include.root.locals.config.eks.endpoint_private_access
  cluster_endpoint_public_access = include.root.locals.config.eks.endpoint_public_access
  cluster_endpoint_public_access_cidrs = try(include.root.locals.config.eks.endpoint_public_access_cidrs, [])
  tags = include.root.locals.tags
}
