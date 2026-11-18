include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/aws-eks/03-modules/05-monitoring"
}

locals {
  cfg                       = include.root.locals.config
  observability_config_path = "${get_repo_root()}/aws-eks/01-config/clients/${local.cfg.client}/${local.cfg.environment}/monitoring-and-logging/${local.cfg.environment}.yaml"
  observability_config      = yamldecode(file(local.observability_config_path))
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

# Needs the gp3 StorageClass for the Prometheus, Grafana, Loki and Tempo PVCs.
dependency "storage" {
  config_path = "../04-storage"
  mock_outputs = {
    block_storage_class_name = try(local.cfg.storage.block.storage_class_name, "gp3")
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# The LB controller webhooks must be up before any Service is created.
dependencies {
  paths = ["../05-cluster-addons"]
}

inputs = {
  observability_config   = local.observability_config
  grafana_admin_username = local.observability_config.credentials.grafana.username
  grafana_admin_password = get_env(local.observability_config.credentials.grafana.password_env, "")
  storage_class_name     = dependency.storage.outputs.block_storage_class_name

  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  region                             = local.cfg.aws.region
  aws_profile                        = local.cfg.aws.profile
  kube_role_arn                      = local.cfg.aws.assume_deploy_role ? local.cfg.bootstrap.deploy_role_arn : ""
}
