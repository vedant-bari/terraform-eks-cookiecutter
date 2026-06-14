locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

#################################################
# Terraform Source (EKS Module)
#################################################

terraform {
  source = "../../../02-modules/04-eks"
}

#################################################
# IAM Role (Execution Role)
#################################################

iam_role = local.env.locals.execution_role_arn

#################################################
# Dependencies
#################################################

dependency "vpc" {
  config_path = "../vpc"
}

dependency "iam" {
  config_path = "../iam"
}

#################################################
# Remote State Configuration
#################################################

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

#################################################
# Inputs for EKS Module
#################################################

inputs = {

  #################################################
  # Cluster Configuration
  #################################################

  cluster_name       = local.env.locals.eks.cluster_name
  kubernetes_version = local.env.locals.eks.kubernetes_version
  environment        = local.env.locals.environment

  #################################################
  # Networking
  #################################################

  vpc_id              = dependency.vpc.outputs.vpc_id
  private_subnet_ids  = dependency.vpc.outputs.private_subnet_ids

  #################################################
  # IAM Roles (created in IAM module)
  #################################################

  cluster_role_arn = dependency.iam.outputs.cluster_role_arn
  node_role_arn    = dependency.iam.outputs.node_role_arn

  #################################################
  # Endpoint Access
  #################################################

  endpoint_public_access  = local.env.locals.eks.endpoint_public_access
  endpoint_private_access = local.env.locals.eks.endpoint_private_access
  public_access_cidrs     = local.env.locals.eks.public_access_cidrs

  #################################################
  # Cluster Logging
  #################################################

  enabled_cluster_log_types = local.env.locals.eks.enabled_cluster_log_types

  #################################################
  # Tags
  #################################################

  tags = merge(
    local.env.locals.tags,
    {
      Component = "eks"
    }
  )

  #################################################
  # Node Groups Configuration
  #################################################

  system_node_group = local.env.locals.eks.node_groups.system

  application_node_group = local.env.locals.eks.node_groups.application
}
