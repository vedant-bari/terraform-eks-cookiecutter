locals {
  # 1. Dynamically extract client name and environment from the path structure
  path_parts  = split("/", get_path_from_repo_root())
  client_name = length(local.path_parts) >= 4 ? local.path_parts[3] : "client-a"
  env_name    = length(local.path_parts) >= 5 ? local.path_parts[4] : "dev"

  # 2. Path to your dev.yaml file inside the infra folder
  yaml_path   = "${get_repo_root()}/gcp-gke/12-platform-config/clients/${local.client_name}/${local.env_name}/infra/${local.env_name}.yaml"
  
  # FIX: Use try() instead of a ternary conditional operator to prevent type mismatches
  yaml_data   = try(yamldecode(file(local.yaml_path)), {})

  # 3. Map sections safely using try() for individual properties
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
}

# 4. Dynamic Remote State Backend configuration
remote_state {
  backend = "gcs"
  config = {
    bucket   = local.config.bootstrap.state_bucket_name
    prefix   = "${get_path_from_repo_root()}/terraform.tfstate"
    project  = local.config.gcp.project_id
    location = local.config.gcp.region
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}