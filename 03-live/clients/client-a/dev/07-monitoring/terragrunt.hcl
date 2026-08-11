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

inputs = {
  cluster_name       = dependency.eks.outputs.cluster_name
  namespace          = include.root.locals.config.monitoring.namespace
  chart_version      = include.root.locals.config.monitoring.chart_version
  storage_class_name = dependency.ebs.outputs.storage_class_name
}
