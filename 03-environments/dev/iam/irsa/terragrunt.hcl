locals {
  env = read_terragrunt_config(
    find_in_parent_folders("env.hcl")
  )
}

terraform {
  source = "../../../../modules/iam/irsa"
}

iam_role = local.env.locals.execution_role_arn

dependency "eks" {
  config_path = "../../eks"
}

dependency "policies" {
  config_path = "../policies"
}

remote_state {
  backend = "s3"

  config = {
    bucket       = local.env.locals.backend.bucket
    key          = "${local.env.locals.backend.key}/iam/irsa/terraform.tfstate"
    region       = local.env.locals.backend.region
    encrypt      = true
    use_lockfile = true
  }

  generate {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

inputs = {
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  oidc_provider_url = dependency.eks.outputs.oidc_provider_url

  roles = {
    external_dns = {
      role_name       = "external-dns-irsa"
      namespace       = "external-dns"
      service_account = "external-dns"

      policy_arns = [
        dependency.policies.outputs.policy_arns["external_dns"]
      ]
    }
  }

  tags = {
    Environment = local.env.locals.environment
    ManagedBy   = "Terraform"
  }
}