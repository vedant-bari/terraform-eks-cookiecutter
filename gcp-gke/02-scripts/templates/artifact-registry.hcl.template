include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/gcp-gke/03-modules/11-artifact-registry"
}

dependency "gke" {
  config_path = "../02-gke"
  mock_outputs = {
    cluster_name    = "gke-cluster"
    service_account = "mock-sa@developer.gserviceaccount.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate"]
}

locals {
  client_name   = include.root.locals.config.client.name
  env_name      = include.root.locals.config.environment
  repository_id = "${local.client_name}-${local.env_name}-repo"
}

inputs = {
  project_id           = include.root.locals.config.gcp.project_id
  region               = include.root.locals.config.gcp.region
  cluster_name         = dependency.gke.outputs.cluster_name
  node_service_account = dependency.gke.outputs.service_account
  repository_id        = local.repository_id
}