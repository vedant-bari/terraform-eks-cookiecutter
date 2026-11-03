locals {
  rel_path    = try(path_relative_to_include(), "")
  path_tokens = split("/", local.rel_path)

  is_client_env = length(local.path_tokens) >= 3 && local.path_tokens[0] == "clients"
  client_name   = local.is_client_env ? local.path_tokens[1] : ""
  env_name      = local.is_client_env ? local.path_tokens[2] : ""

  repo_root = get_repo_root()
  yaml_path = local.is_client_env ? "${local.repo_root}/aws-eks/12-platform-config/clients/${local.client_name}/${local.env_name}/infra/${local.env_name}.yaml" : ""

  # Provide a consistent typed fallback map to satisfy Terraform's conditional type checks
  default_config = {
    client    = { name = "" }
    environment = ""
    aws       = { project_id = "", region = "us-east-1", zone = "", tags = {} }
    bootstrap = { state_bucket_name = "default-tf-state", force_destroy = false, uniform_bucket_level_access = true }
  }

  infra_config = local.yaml_path != "" && fileexists(local.yaml_path) ? yamldecode(file(local.yaml_path)) : local.default_config
}

remote_state {
  backend = "s3"
  config = {
    bucket       = lookup(try(local.infra_config.bootstrap, {}), "state_bucket_name", "default-tf-state-bucket")
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = lookup(try(local.infra_config.aws, {}), "region", "us-east-1")
    encrypt      = true
    use_lockfile = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}