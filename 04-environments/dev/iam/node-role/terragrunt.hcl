locals {
  env = read_terragrunt_config(
    find_in_parent_folders("env.hcl")
  )
}

terraform {
  source = "../../../../02-modules/03-iam/node-role"
}

iam_role = local.env.locals.execution_role_arn

remote_state {
  backend = "s3"

  config = {
    bucket       = local.env.locals.backend.bucket
    key          = "${local.env.locals.backend.key}/iam/node-role/terraform.tfstate"
    region       = local.env.locals.backend.region
    encrypt      = true
    use_lockfile = true
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

inputs = {
  role_name = local.env.locals.iam.node_role_name

  tags = {
    Environment = local.env.locals.environment
    ManagedBy   = "Terraform"
    Component   = "eks-node-role"
  }
}