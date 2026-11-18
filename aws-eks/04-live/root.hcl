# ==============================================================================
# aws-eks root Terragrunt configuration.
# Every live unit includes this file with `expose = true` and reads
# include.root.locals.config.*.
#
# - client/env come from the live path: aws-eks/04-live/clients/<client>/<env>/<layer>
# - config comes from aws-eks/01-config/clients/<client>/<env>/infra/<env>.yaml
#   (a missing or invalid file is a hard error; there are no silent fallbacks)
# - generates backend.tf (S3 + native lockfile) and provider.tf (aws provider
#   with region, default_tags, allowed_account_ids and deploy-role assumption)
#
# Modules must NOT declare their own `provider "aws"` block.
# ==============================================================================

locals {
  path_parts = split("/", get_path_from_repo_root())
  # aws-eks / 04-live / clients / <client> / <env> / <layer>
  client_name = local.path_parts[3]
  env_name    = local.path_parts[4]
  layer_name  = local.path_parts[length(local.path_parts) - 1]

  yaml_path = "${get_repo_root()}/aws-eks/01-config/clients/${local.client_name}/${local.env_name}/infra/${local.env_name}.yaml"
  yaml_data = yamldecode(file(local.yaml_path))

  account_id  = tostring(local.yaml_data.aws.account_id)
  region      = local.yaml_data.aws.region
  profile     = try(local.yaml_data.aws.profile, "")
  name_prefix = "${local.client_name}-${local.env_name}"

  bootstrap = try(local.yaml_data.bootstrap, {})
  state_bucket_name = (
    try(local.bootstrap.state_bucket_name, "") != ""
    ? local.bootstrap.state_bucket_name
    : "${local.name_prefix}-tfstate-${local.account_id}"
  )
  deploy_role_name = (
    try(local.bootstrap.deploy_role.name, "") != ""
    ? local.bootstrap.deploy_role.name
    : "${local.name_prefix}-terraform-deploy"
  )
  deploy_role_arn = "arn:aws:iam::${local.account_id}:role/${local.deploy_role_name}"

  # 00-bootstrap creates the deploy role, so it always runs with the caller's own credentials.
  assume_deploy_role = try(local.yaml_data.aws.assume_deploy_role, true) && local.layer_name != "00-bootstrap"

  config = {
    client      = local.client_name
    environment = local.env_name
    name_prefix = local.name_prefix

    aws = {
      account_id = local.account_id
      region     = local.region
      profile    = local.profile
      tags       = try(local.yaml_data.aws.tags, {})
    }

    bootstrap = merge(local.bootstrap, {
      state_bucket_name = local.state_bucket_name
      deploy_role_name  = local.deploy_role_name
      deploy_role_arn   = local.deploy_role_arn
    })

    budget = try(local.yaml_data.budget, {})
    vpc    = try(local.yaml_data.vpc, {})
  }

  # Stable logical state identity; preserve these keys across live-directory renames.
  state_layer_keys = {
    "00-bootstrap"      = "bootstrap"
    "01-network"        = "network"
    "02-eks"            = "eks"
    "03-ecr"            = "ecr"
    "04-storage"        = "storage"
    "05-cluster-addons" = "cluster-addons"
    "06-monitoring"     = "monitoring"
    "07-jenkins"        = "jenkins"
    "08-applications"   = "applications"
  }
  state_layer_key = lookup(local.state_layer_keys, local.layer_name, local.layer_name)

  offline = tobool(get_env("AWS_EKS_OFFLINE", "false"))

  provider_profile_line = local.profile != "" ? "profile = \"${local.profile}\"" : ""
  provider_assume_block = local.assume_deploy_role ? join("\n", [
    "  assume_role {",
    "    role_arn     = \"${local.deploy_role_arn}\"",
    "    session_name = \"terragrunt-${local.name_prefix}-${local.state_layer_key}\"",
    "  }",
  ]) : ""
}

# AWS_EKS_OFFLINE=true switches to a throwaway local backend so `validate` and
# the repo validator can run without credentials or the state bucket.
# Never plan or apply in offline mode.
remote_state {
  backend = local.offline ? "local" : "s3"
  config = local.offline ? {
    path = "${get_terragrunt_dir()}/.offline.tfstate"
    } : merge(
    {
      bucket       = local.state_bucket_name
      key          = "aws-eks/${local.client_name}/${local.env_name}/${local.state_layer_key}/terraform.tfstate"
      region       = local.region
      encrypt      = true
      use_lockfile = true
    },
    local.profile != "" ? { profile = local.profile } : {}
  )
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region              = "${local.region}"
      allowed_account_ids = ["${local.account_id}"]
      ${local.provider_profile_line}
    ${local.provider_assume_block}

      default_tags {
        tags = ${jsonencode(local.config.aws.tags)}
      }
    }
  EOF
}
