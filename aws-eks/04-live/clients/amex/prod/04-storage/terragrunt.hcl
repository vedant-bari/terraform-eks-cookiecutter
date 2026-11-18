include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/aws-eks/03-modules/07-storage-class"
}

locals {
  cfg     = include.root.locals.config
  storage = local.cfg.storage
}

dependency "network" {
  config_path = "../01-network"
  mock_outputs = {
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = [for i, az in local.cfg.vpc.azs : format("subnet-%017d", i)]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "eks" {
  config_path = "../02-eks"
  mock_outputs = {
    cluster_name                       = local.cfg.eks.cluster_name
    cluster_endpoint                   = "https://00000000000000000000000000000000.gr7.${local.cfg.aws.region}.eks.amazonaws.com"
    cluster_certificate_authority_data = "bW9jaw=="
    node_security_group_id             = "sg-00000000000000000"
    cluster_primary_security_group_id  = "sg-00000000000000001"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  region                             = local.cfg.aws.region
  aws_profile                        = local.cfg.aws.profile
  kube_role_arn                      = local.cfg.aws.assume_deploy_role ? local.cfg.bootstrap.deploy_role_arn : ""

  name_prefix        = local.cfg.name_prefix
  vpc_id             = dependency.network.outputs.vpc_id
  private_subnet_ids = dependency.network.outputs.private_subnet_ids
  nfs_client_security_group_ids = [
    dependency.eks.outputs.node_security_group_id,
    dependency.eks.outputs.cluster_primary_security_group_id,
  ]

  block_storage_class_name = try(local.storage.block.storage_class_name, "gp3")
  block_kms_key_arn        = try(local.storage.block.kms_key_arn, "")

  rwx_storage_class_name = try(local.storage.rwx.storage_class_name, "") != "" ? local.storage.rwx.storage_class_name : "${local.cfg.name_prefix}-rwx"
  efs_throughput_mode    = try(local.storage.rwx.throughput_mode, "elastic")
  efs_transition_to_ia   = try(local.storage.rwx.transition_to_ia, "")
  efs_backup_enabled     = try(local.storage.rwx.backup_enabled, false)
  efs_uid                = try(local.storage.rwx.uid, 1000)
  efs_gid                = try(local.storage.rwx.gid, 1000)
  efs_directory_perms    = try(local.storage.rwx.directory_perms, "700")
}
