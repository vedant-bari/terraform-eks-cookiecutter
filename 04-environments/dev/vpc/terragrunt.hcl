locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../../modules/vpc"
}

iam_role = local.env.locals.execution_role_arn

remote_state {
  backend = "s3"

  config = {
    bucket       = local.env.locals.backend.bucket
    key          = "${local.env.locals.backend.key}/vpc/terraform.tfstate"
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
  name = local.env.locals.vpc.name

  cidr = local.env.locals.vpc.cidr

  azs = local.env.locals.vpc.azs

  private_subnets = local.env.locals.vpc.private_subnets

  public_subnets = local.env.locals.vpc.public_subnets

  database_subnets = local.env.locals.vpc.database_subnets

  public_subnet_tags = {
    Type = "public-subnets"
  }

  private_subnet_tags = {
    Type = "private-subnets"
  }

  database_subnet_tags = {
    Type = "database-subnets"
  }

  tags = {
    Owner      = "kalyan"
    Environment = local.env.locals.environment
    ManagedBy  = "Terraform"
  }

  vpc_tags = {
    Name = local.env.locals.vpc.name
  }
}