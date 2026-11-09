include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
terraform {
  source = "${get_repo_root()}/aws-eks/03-modules/08-logging"
}
dependency "eks" {
  config_path = "../03-eks"
  mock_outputs = { cluster_name = "example-eks" }
  mock_outputs_allowed_terraform_commands = ["init", "validate"]
}
dependency "monitoring" {
  config_path = "../06-monitoring"
  mock_outputs = { namespace = "monitoring" }
  mock_outputs_allowed_terraform_commands = ["init", "validate"]
}
dependency "ebs" {
  config_path = "../04-ebs-csi"
  mock_outputs = { storage_class_name = "ebs-gp3" }
  mock_outputs_allowed_terraform_commands = ["init", "validate"]
}
locals {
  override_path = "${get_repo_root()}/aws-eks/01-config/${include.root.locals.config.logging.override_values_file}"
  override = yamldecode(file(local.override_path))
}
inputs = {
  cluster_name       = dependency.eks.outputs.cluster_name
  namespace          = dependency.monitoring.outputs.namespace
  storage_class_name = dependency.ebs.outputs.storage_class_name
  loki_chart_version = include.root.locals.config.logging.loki_chart_version
  alloy_chart_version = include.root.locals.config.logging.alloy_chart_version
  loki_values        = yamlencode(local.override.loki)
  alloy_values       = yamlencode(local.override.alloy)
}
