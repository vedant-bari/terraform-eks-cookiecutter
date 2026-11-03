include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/gcp-gke/02-modules/06-app-deploy"
}

dependency "gke" {
  config_path = "../04-gke"
  mock_outputs = {
    cluster_endpoint       = "0.0.0.0"
    cluster_ca_certificate = "bW9jay1jZXJ0"
  }
}

locals {
  client_name = include.root.locals.config.client.name
  apps_dir    = "${get_repo_root()}/gcp-gke/12-platform-config/clients/${local.client_name}/apps"
  
  app_files   = fileset(local.apps_dir, "*.yaml")

  # Encode each decoded YAML map into a JSON string to satisfy map(string) typing
  apps = {
    for f in local.app_files : 
    replace(replace(f, "-values.yaml", ""), ".yaml", "") => jsonencode(yamldecode(file("${local.apps_dir}/${f}")))
  }
}

inputs = {
  project_id             = include.root.locals.config.gcp.project_id
  chart_path             = "${get_repo_root()}/gcp-gke/13-helm-charts-app/generic-app"
  
  apps                   = local.apps

  cluster_endpoint       = dependency.gke.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.gke.outputs.cluster_ca_certificate
}