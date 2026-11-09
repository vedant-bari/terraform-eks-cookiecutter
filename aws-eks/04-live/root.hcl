locals {
  path_parts  = split("/", get_path_from_repo_root())
  client_name = length(local.path_parts) >= 5 ? local.path_parts[3] : "client-a"
  env_name    = length(local.path_parts) >= 5 ? local.path_parts[4] : "dev"

  config_path = "${get_repo_root()}/aws-eks/01-config/clients/${local.client_name}/${local.env_name}/infra/${local.env_name}.yaml"
  config      = yamldecode(file(local.config_path))

  aws_region = local.config.aws.region
  tags       = try(local.config.aws.tags, {})

  layer_name = local.path_parts[length(local.path_parts) - 1]
  state_layer_keys = {
    "00-bootstrap" = "bootstrap"
    "01-network" = "network"
    "02-bastion" = "bastion"
    "03-eks" = "eks"
    "04-ebs-csi" = "ebs-csi"
    "05-efs-csi" = "efs-csi"
    "06-monitoring" = "monitoring"
    "07-logging" = "logging"
    "08-applications" = "applications"
  }
  state_layer_key = lookup(local.state_layer_keys, local.layer_name, local.layer_name)
}

remote_state {
  backend = "s3"
  config = {
    bucket       = local.config.bootstrap.state_bucket_name
    key          = "aws-eks/${local.client_name}/${local.env_name}/${local.state_layer_key}/terraform.tfstate"
    region       = local.aws_region
    encrypt      = true
    use_lockfile = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"

  default_tags {
    tags = ${jsonencode(local.tags)}
  }
}
EOF
}
