include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/aws-eks/03-modules/07-monitoring"
}

dependency "eks" {
  config_path = "../03-eks"
  mock_outputs = { cluster_name = "example-eks" }
  mock_outputs_allowed_terraform_commands = ["init", "validate"]
}

dependency "ebs" {
  config_path = "../04-ebs-csi"
  mock_outputs = { storage_class_name = "ebs-gp3" }
  mock_outputs_allowed_terraform_commands = ["init", "validate"]
}

locals {
  override_path = "${get_repo_root()}/aws-eks/01-config/${include.root.locals.config.monitoring.override_values_file}"
  override = yamldecode(file(local.override_path))
}

inputs = {
  cluster_name = dependency.eks.outputs.cluster_name
  namespace = include.root.locals.config.monitoring.namespace
  chart_version = include.root.locals.config.monitoring.chart_version
  storage_class_name = dependency.ebs.outputs.storage_class_name
  monitoring_values = yamlencode(local.override.monitoring)
}
