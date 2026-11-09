include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
terraform {
  source = "${get_repo_root()}/aws-eks/03-modules/09-app-deploy"
}
dependency "eks" {
  config_path = "../03-eks"
  mock_outputs = { cluster_name = "example-eks" }
  mock_outputs_allowed_terraform_commands = ["init", "validate"]
}
dependencies {
  paths = ["../04-ebs-csi", "../05-efs-csi", "../06-monitoring", "../07-logging"]
}
locals {
  apps_dir = "${get_repo_root()}/aws-eks/01-config/clients/${include.root.locals.client_name}/${include.root.locals.env_name}/applications"
  app_files = try(fileset(local.apps_dir, "*.yaml"), [])
  raw_apps = {
    for filename in local.app_files :
    trimsuffix(filename, ".yaml") => yamldecode(file("${local.apps_dir}/${filename}"))
  }
  enabled_apps = try(include.root.locals.config.applications.enabled, false) ? local.raw_apps : {}
}
inputs = {
  cluster_name = dependency.eks.outputs.cluster_name
  chart_path   = "${get_repo_root()}/aws-eks/05-helm-charts/generic-app"
  apps         = local.enabled_apps
}
