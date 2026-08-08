include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_parent_terragrunt_dir()}/../02-modules/04-eks"
}

dependency "vpc" {
  config_path = "../02-vpc"
  
  mock_outputs = {
    vpc_id             = "vpc-mock-id-123"
    private_subnet_ids = ["subnet-mock-1", "subnet-mock-2"]
  }
}

inputs = {
  cluster_name    = include.root.locals.config.eks.cluster_name
  cluster_version = include.root.locals.config.eks.cluster_version
  
  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  
  # Injecting our Production Best Practices
  node_groups               = include.root.locals.config.eks.node_groups
  cluster_enabled_log_types = include.root.locals.config.eks.cluster_enabled_log_types

  # NEW: Pass the toggle from YAML down to Terraform
  create_cloudwatch_log_group = include.root.locals.config.eks.create_cloudwatch_log_group

  cluster_addons = include.root.locals.config.eks.cluster_addons
  tags           = include.root.locals.config.eks.tags
}