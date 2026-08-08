locals {
  # 1. Parse the path assuming this file sits at 03-live/root.hcl
  path_parts = split("/", path_relative_to_include())
  
  # path_relative_to_include() will output: "clients/client-a/dev/02-vpc"
  # Index 0: "clients"
  # Index 1: "client-a"
  # Index 2: "dev"
  
  client_name = local.path_parts[1]
  env_name    = local.path_parts[2]

  # 2. Safely locate the 12-platform-config folder relative to 03-live/
  yaml_file_path = "${get_parent_terragrunt_dir()}/../12-platform-config/clients/${local.client_name}/${local.env_name}.yaml"

  # 3. Decode the YAML
  config     = yamldecode(file(local.yaml_file_path))
  aws_region = local.config.client.region
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
  default_tags {
    tags = {
      Environment = "${local.env_name}"
      Client      = "${local.client_name}"
      ManagedBy   = "Terragrunt"
    }
  }
}
EOF
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "s3" {
    bucket       = "tf-state-${local.client_name}"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = "${local.aws_region}"
    encrypt      = true
    use_lockfile = true 
  }
}
EOF
}