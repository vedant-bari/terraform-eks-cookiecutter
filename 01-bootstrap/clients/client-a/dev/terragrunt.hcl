locals {
  # 1. Dynamically extract the client and environment names from the folder path
  # Directory structure: .../01-bootstrap/clients/client-a/dev
  path_parts  = split("/", get_original_terragrunt_dir())
  env_name    = local.path_parts[length(local.path_parts) - 1]
  client_name = local.path_parts[length(local.path_parts) - 2]

  # 2. Safely locate the YAML file relative to this directory (up 4 levels)
  yaml_file_path = "${get_original_terragrunt_dir()}/../../../../12-platform-config/clients/${local.client_name}/${local.env_name}.yaml"
  
  # 3. Decode the YAML
  config = yamldecode(file(local.yaml_file_path))
}

# 4. Generate the AWS provider using the region directly from the YAML
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.config.client.region}"
  default_tags {
    tags = {
      Environment = "${local.env_name}"
      Client      = "${local.client_name}"
      ManagedBy   = "Terragrunt-Bootstrap"
    }
  }
}
EOF
}

terraform {
  # Point up 4 levels, then into the 02-modules directory
  source = "${get_original_terragrunt_dir()}/../../../../02-modules/01-bootstrap"
}

# 5. Inject the variables parsed from the YAML into the Terraform module
inputs = {
  bucket_name = local.config.bootstrap.bucket_name
  kms_alias   = local.config.bootstrap.kms_alias
  environment = local.env_name
}