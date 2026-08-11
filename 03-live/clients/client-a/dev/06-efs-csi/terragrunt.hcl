include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_parent_terragrunt_dir()}/../02-modules/06-efs-csi"
}

dependency "vpc" {
  config_path = "../02-vpc"

  mock_outputs = {
    vpc_id             = "vpc-mock-id"
    private_subnet_ids = ["subnet-mock-1", "subnet-mock-2"]
  }
}

dependency "eks" {
  config_path = "../04-eks"

  mock_outputs = {
    cluster_name            = "eks-mock"
    oidc_provider_arn       = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.ap-south-1.amazonaws.com/id/mock"
    cluster_oidc_issuer_url = "https://oidc.eks.ap-south-1.amazonaws.com/id/mock"
    node_security_group_id  = "sg-mock-id"
  }
}

inputs = {
  cluster_name            = dependency.eks.outputs.cluster_name
  oidc_provider_arn       = dependency.eks.outputs.oidc_provider_arn
  cluster_oidc_issuer_url = dependency.eks.outputs.cluster_oidc_issuer_url
  node_security_group_id  = dependency.eks.outputs.node_security_group_id

  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids

  create_efs                 = include.root.locals.config.efs.create
  existing_efs_file_system_id = include.root.locals.config.efs.existing_id
  storage_class_name         = include.root.locals.config.efs.storage_class_name
  access_point_base_path     = include.root.locals.config.efs.access_point_base_path
  transition_to_ia           = include.root.locals.config.efs.transition_to_ia
  addon_version              = try(include.root.locals.config.efs.addon_version, null)
  reclaim_policy             = include.root.locals.config.efs.reclaim_policy
  tags                       = include.root.locals.config.eks.tags
}
