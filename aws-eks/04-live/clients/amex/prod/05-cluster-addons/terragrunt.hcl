include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/aws-eks/03-modules/09-cluster-addons"
}

locals {
  cfg    = include.root.locals.config
  addons = local.cfg.cluster_addons
}

dependency "network" {
  config_path = "../01-network"
  mock_outputs = {
    vpc_id = "vpc-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "eks" {
  config_path = "../02-eks"
  mock_outputs = {
    cluster_name                       = local.cfg.eks.cluster_name
    cluster_endpoint                   = "https://00000000000000000000000000000000.gr7.${local.cfg.aws.region}.eks.amazonaws.com"
    cluster_certificate_authority_data = "bW9jaw=="
    kubernetes_version                 = local.cfg.eks.kubernetes_version
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  kubernetes_version                 = dependency.eks.outputs.kubernetes_version
  region                             = local.cfg.aws.region
  aws_profile                        = local.cfg.aws.profile
  kube_role_arn                      = local.cfg.aws.assume_deploy_role ? local.cfg.bootstrap.deploy_role_arn : ""

  vpc_id        = dependency.network.outputs.vpc_id
  resource_tags = local.cfg.aws.tags

  lb_controller = {
    chart_version   = local.addons.lb_controller.chart_version
    replica_count   = try(local.addons.lb_controller.replica_count, 2)
    service_account = try(local.addons.lb_controller.service_account, "aws-load-balancer-controller")
  }

  cluster_autoscaler = {
    chart_version   = local.addons.cluster_autoscaler.chart_version
    image_tag       = local.addons.cluster_autoscaler.image_tag
    service_account = try(local.addons.cluster_autoscaler.service_account, "cluster-autoscaler")
    extra_args      = try(local.addons.cluster_autoscaler.extra_args, {})
  }
}
