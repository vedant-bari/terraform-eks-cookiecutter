locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=v21.0.0"
}

iam_role = local.env.locals.execution_role_arn

dependency "vpc" {
  config_path = "../vpc"
}

remote_state {
  backend = "s3"

  config = {
    bucket       = local.env.locals.backend.bucket
    key          = "${local.env.locals.backend.key}/eks/terraform.tfstate"
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
  cluster_name       = local.env.locals.eks.cluster_name
  cluster_version    = local.env.locals.eks.cluster_version

  vpc_id             = dependency.vpc.outputs.vpc_id
  subnet_ids         = dependency.vpc.outputs.private_subnet_ids

  node_groups        = local.env.locals.eks.node_groups
}