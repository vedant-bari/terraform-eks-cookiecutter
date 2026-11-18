include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/aws-eks/03-modules/04-eks"
}

locals {
  cfg = include.root.locals.config
  eks = local.cfg.eks
}

dependency "network" {
  config_path = "../01-network"

  # Mocks let a fresh environment be planned before 01-network exists (D11).
  # deploy-env.sh applies layers one by one, so real applies use real outputs.
  mock_outputs = {
    vpc_id                   = "vpc-00000000000000000"
    private_subnet_ids       = [for i, az in local.cfg.vpc.azs : format("subnet-%017d", i)]
    private_subnet_ids_by_az = { for i, az in local.cfg.vpc.azs : az => format("subnet-%017d", i) }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  cluster_name         = local.eks.cluster_name
  kubernetes_version   = local.eks.kubernetes_version
  upgrade_support_type = try(local.eks.upgrade_support_type, "STANDARD")
  deletion_protection  = try(local.eks.deletion_protection, false)
  service_ipv4_cidr    = local.eks.service_ipv4_cidr

  vpc_id                   = dependency.network.outputs.vpc_id
  private_subnet_ids       = dependency.network.outputs.private_subnet_ids
  private_subnet_ids_by_az = dependency.network.outputs.private_subnet_ids_by_az

  # Class-B toggles; defaults = GCP parity (public endpoint open to all).
  endpoint_public_access_cidrs = try(local.eks.endpoint.public_access_cidrs, ["0.0.0.0/0"])
  endpoint_private_only        = try(local.eks.endpoint.private_only, false)

  assume_deploy_role   = local.cfg.aws.assume_deploy_role
  deploy_role_arn      = local.cfg.bootstrap.deploy_role_arn
  admin_principal_arns = try(local.eks.admin_principal_arns, [])
  enable_irsa          = try(local.eks.enable_irsa, false)

  control_plane_log_types          = try(local.eks.control_plane_logs.types, ["api", "audit", "authenticator"])
  control_plane_log_retention_days = try(local.eks.control_plane_logs.retention_days, 7)

  node_azs   = local.eks.node_azs
  node_group = local.eks.node_group
  max_pods   = try(local.eks.max_pods, 110)

  prefix_delegation          = try(local.eks.vpc_cni.prefix_delegation, true)
  network_policy_enabled     = try(local.eks.network_policy.enabled, false)
  container_insights_enabled = try(local.eks.container_insights.enabled, false)
  addon_versions             = try(local.eks.addon_versions, {})

  resource_tags = local.cfg.aws.tags
}
