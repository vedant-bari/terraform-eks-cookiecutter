include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_parent_terragrunt_dir()}/../02-modules/05-ebs-csi"
}

dependency "eks" {
  config_path = "../04-eks"

  mock_outputs = {
    cluster_name            = "eks-mock"
    oidc_provider_arn       = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.ap-south-1.amazonaws.com/id/mock"
    cluster_oidc_issuer_url = "https://oidc.eks.ap-south-1.amazonaws.com/id/mock"
  }
}

inputs = {
  cluster_name            = dependency.eks.outputs.cluster_name
  oidc_provider_arn       = dependency.eks.outputs.oidc_provider_arn
  cluster_oidc_issuer_url = dependency.eks.outputs.cluster_oidc_issuer_url

  storage_class_name          = include.root.locals.config.ebs.storage_class_name
  create_ebs                  = include.root.locals.config.ebs.create
  existing_ebs_volume_id      = include.root.locals.config.ebs.existing_id
  existing_ebs_pv_name        = include.root.locals.config.ebs.existing_pv_name
  existing_ebs_pvc_name       = include.root.locals.config.ebs.existing_pvc_name
  existing_ebs_pvc_namespace  = include.root.locals.config.ebs.existing_pvc_namespace
  existing_ebs_fs_type        = include.root.locals.config.ebs.existing_fs_type
  addon_version               = try(include.root.locals.config.ebs.addon_version, null)
  reclaim_policy              = include.root.locals.config.ebs.reclaim_policy
  tags                        = include.root.locals.config.eks.tags
}
