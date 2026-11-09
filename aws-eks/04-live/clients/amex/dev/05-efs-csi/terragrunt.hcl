include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/aws-eks/03-modules/06-efs-csi"
}

dependency "eks" {
  config_path = "../03-eks"
  mock_outputs = {
    cluster_name = "example-eks"
    oidc_provider_arn = "arn:aws:iam::111111111111:oidc-provider/oidc.eks.ap-south-1.amazonaws.com/id/EXAMPLE"
    cluster_oidc_issuer_url = "https://oidc.eks.ap-south-1.amazonaws.com/id/EXAMPLE"
    node_security_group_id = "sg-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate"]
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
  cluster_name = dependency.eks.outputs.cluster_name
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  cluster_oidc_issuer_url = dependency.eks.outputs.cluster_oidc_issuer_url
  vpc_id = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  node_security_group_id = dependency.eks.outputs.node_security_group_id
  create_efs = include.root.locals.config.efs.create
  existing_efs_file_system_id = try(include.root.locals.config.efs.existing_id, "")
  storage_class_name = include.root.locals.config.efs.storage_class_name
  access_point_base_path = try(include.root.locals.config.efs.access_point_base_path, "/dynamic_provisioning")
  transition_to_ia = try(include.root.locals.config.efs.transition_to_ia, "AFTER_30_DAYS")
  addon_version = try(include.root.locals.config.efs.addon_version, null)
  reclaim_policy = try(include.root.locals.config.efs.reclaim_policy, "Delete")
  tags = include.root.locals.tags
}
