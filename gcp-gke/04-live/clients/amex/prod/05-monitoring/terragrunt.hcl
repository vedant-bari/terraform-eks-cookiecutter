include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/gcp-gke/03-modules/05-monitoring"
}

dependency "gke" {
  config_path = "../02-gke"
  mock_outputs = {
    cluster_endpoint       = "0.0.0.0"
    cluster_ca_certificate = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate"]
}

locals {
  path_parts                = split("/", get_path_from_repo_root())
  client_name               = local.path_parts[3]
  env_name                  = local.path_parts[4]
  observability_config_path = "${get_repo_root()}/gcp-gke/01-config/clients/${local.client_name}/${local.env_name}/monitoring-and-logging/${local.env_name}.yaml"
  observability_config      = yamldecode(file(local.observability_config_path))
}

inputs = {
  observability_config      = local.observability_config
  grafana_admin_username    = local.observability_config.credentials.grafana.username
  grafana_admin_password    = get_env(local.observability_config.credentials.grafana.password_env)
  cluster_endpoint          = dependency.gke.outputs.cluster_endpoint
  cluster_ca_certificate    = dependency.gke.outputs.cluster_ca_certificate
}
