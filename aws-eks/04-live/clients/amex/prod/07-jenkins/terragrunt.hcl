include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/aws-eks/03-modules/10-jenkins"
}

locals {
  cfg     = include.root.locals.config
  jenkins = try(local.cfg.jenkins, {})

  jenkins_dir = "${get_repo_root()}/aws-eks/01-config/clients/${local.cfg.client}/${local.cfg.environment}/jenkins"
  yaml_path   = "${local.jenkins_dir}/${local.cfg.environment}.yaml"

  # "rwx" = EFS (GCP parity, Filestore RWX); "block" = gp3, faster, single replica only.
  home_storage = try(local.jenkins.persistence.storage, "rwx")
}

dependency "eks" {
  config_path = "../02-eks"
  mock_outputs = {
    cluster_name                       = local.cfg.eks.cluster_name
    cluster_endpoint                   = "https://00000000000000000000000000000000.gr7.${local.cfg.aws.region}.eks.amazonaws.com"
    cluster_certificate_authority_data = "bW9jaw=="
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "storage" {
  config_path = "../04-storage"
  mock_outputs = {
    rwx_storage_class_name   = "${local.cfg.name_prefix}-rwx"
    block_storage_class_name = "gp3"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# The Ingress needs the AWS Load Balancer Controller (ALB, IngressClass "alb").
dependencies {
  paths = ["../05-cluster-addons"]
}

inputs = {
  yaml_path     = local.yaml_path
  chart_version = try(local.jenkins.chart_version, "5.10.0")

  storage_class = local.home_storage == "block" ? dependency.storage.outputs.block_storage_class_name : dependency.storage.outputs.rwx_storage_class_name
  access_mode   = local.home_storage == "block" ? "ReadWriteOnce" : "ReadWriteMany"

  ecr_repository_namespace = local.cfg.name_prefix

  # Class-B toggle; true = GCP parity.
  cluster_wide_rbac = try(local.jenkins.cluster_wide_rbac, true)

  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  region                             = local.cfg.aws.region
  aws_profile                        = local.cfg.aws.profile
  kube_role_arn                      = local.cfg.aws.assume_deploy_role ? local.cfg.bootstrap.deploy_role_arn : ""
}
