include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/aws-eks/03-modules/05-ebs-csi"
}

dependency "eks" {
  config_path = "../03-eks"
  mock_outputs = {
    cluster_name = "example-eks"
    oidc_provider_arn = "arn:aws:iam::111111111111:oidc-provider/oidc.eks.ap-south-1.amazonaws.com/id/EXAMPLE"
    cluster_oidc_issuer_url = "https://oidc.eks.ap-south-1.amazonaws.com/id/EXAMPLE"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate"]
}

inputs = {
  cluster_name = dependency.eks.outputs.cluster_name
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  cluster_oidc_issuer_url = dependency.eks.outputs.cluster_oidc_issuer_url
  storage_class_name = include.root.locals.config.ebs.storage_class_name
  create_ebs = include.root.locals.config.ebs.create
  existing_ebs_volume_id = try(include.root.locals.config.ebs.existing_id, "")
  existing_ebs_pv_name = try(include.root.locals.config.ebs.existing_pv_name, "existing-ebs-pv")
  existing_ebs_pvc_name = try(include.root.locals.config.ebs.existing_pvc_name, "existing-ebs-pvc")
  existing_ebs_pvc_namespace = try(include.root.locals.config.ebs.existing_pvc_namespace, "default")
  existing_ebs_fs_type = try(include.root.locals.config.ebs.existing_fs_type, "ext4")
  addon_version = try(include.root.locals.config.ebs.addon_version, null)
  reclaim_policy = try(include.root.locals.config.ebs.reclaim_policy, "Delete")
  tags = include.root.locals.tags
}
