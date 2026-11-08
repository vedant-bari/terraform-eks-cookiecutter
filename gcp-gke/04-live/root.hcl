locals {
  # 1. Dynamically extract client name and environment from the path structure
  path_parts  = split("/", get_path_from_repo_root())
  client_name = length(local.path_parts) >= 4 ? local.path_parts[3] : "client-a"
  env_name    = length(local.path_parts) >= 5 ? local.path_parts[4] : "dev"

  # 2. Path to the environment configuration file
  yaml_path = "${get_repo_root()}/gcp-gke/01-config/clients/${local.client_name}/${local.env_name}/infra/${local.env_name}.yaml"

  # Decode configuration safely
  yaml_data = try(yamldecode(file(local.yaml_path)), {})

  # 3. Normalize configuration sections
  config = {
    client      = try(local.yaml_data.client, { name = local.client_name })
    environment = try(local.yaml_data.environment, local.env_name)

    gcp = {
      project_id = try(local.yaml_data.gcp.project_id, "eks-terraform")
      region     = try(local.yaml_data.gcp.region, "asia-south1")
      zone       = try(local.yaml_data.gcp.zone, "asia-south1-a")
      tags       = try(local.yaml_data.gcp.tags, {})
    }

    bootstrap = try(local.yaml_data.bootstrap, {})
    vpc       = try(local.yaml_data.vpc, {})
    bastion   = try(local.yaml_data.bastion, {})
    gke       = try(local.yaml_data.gke, {})
    storage   = try(local.yaml_data.storage, {})
  }

  # Stable logical state identity; preserve these keys across live-directory renames.
  # See 00-documentation/deployment/STATE_LAYOUT_MIGRATION.md before changing this map.
  layer_name = local.path_parts[length(local.path_parts) - 1]
  state_layer_keys = {
    "00-bootstrap"         = "bootstrap"
    "01-network"           = "network"
    "02-gke"               = "gke"
    "03-artifact-registry" = "artifact-registry"
    "04-storage"           = "storage"
    "05-monitoring"        = "monitoring"
    "06-jenkins"           = "jenkins"
    "07-applications"      = "applications"
  }
  state_layer_key = lookup(local.state_layer_keys, local.layer_name, local.layer_name)
}

# 5. Dynamic Remote State Backend configuration
remote_state {
  backend = "gcs"
  config = {
    bucket   = local.config.bootstrap.state_bucket_name
    prefix   = "gcp-gke/${local.client_name}/${local.env_name}/${local.state_layer_key}/terraform.tfstate"
    project  = local.config.gcp.project_id
    location = local.config.gcp.region
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}