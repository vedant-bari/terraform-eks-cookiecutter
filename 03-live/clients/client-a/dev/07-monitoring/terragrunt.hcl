include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_parent_terragrunt_dir()}/../02-modules/07-monitoring"
}

dependency "eks" {
  config_path = "../04-eks"

  mock_outputs = {
    cluster_name = "eks-mock"
  }
}

dependency "ebs" {
  config_path = "../05-ebs-csi"

  mock_outputs = {
    storage_class_name = "ebs-gp3"
  }
}

locals {
  # Paths in monitoring.override_values_file are relative to 12-platform-config.
  platform_config_dir  = "${get_parent_terragrunt_dir()}/../12-platform-config"
  observability_values = yamldecode(file("${local.platform_config_dir}/${include.root.locals.config.monitoring.override_values_file}"))
}

inputs = {
  cluster_name       = dependency.eks.outputs.cluster_name
  namespace          = include.root.locals.config.monitoring.namespace
  chart_version      = include.root.locals.config.monitoring.chart_version
  storage_class_name = dependency.ebs.outputs.storage_class_name
  monitoring_values  = yamlencode(local.observability_values.monitoring)
}
