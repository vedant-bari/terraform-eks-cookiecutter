include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_parent_terragrunt_dir()}/../02-modules/08-logging"
}

dependency "eks" {
  config_path = "../04-eks"

  mock_outputs = {
    cluster_name = "eks-mock"
  }
}

dependency "monitoring" {
  config_path = "../07-monitoring"

  mock_outputs = {
    namespace = "monitoring"
  }
}

locals {
  # This shared override contains separate monitoring, loki, and alloy sections.
  # Its path is relative to 12-platform-config.
  platform_config_dir  = "${get_parent_terragrunt_dir()}/../12-platform-config"
  observability_values = yamldecode(file("${local.platform_config_dir}/${include.root.locals.config.logging.override_values_file}"))
}

inputs = {
  cluster_name        = dependency.eks.outputs.cluster_name
  namespace           = dependency.monitoring.outputs.namespace
  loki_chart_version  = include.root.locals.config.logging.loki_chart_version
  alloy_chart_version = include.root.locals.config.logging.alloy_chart_version
  loki_values         = yamlencode(local.observability_values.loki)
  alloy_values        = yamlencode(local.observability_values.alloy)
}
