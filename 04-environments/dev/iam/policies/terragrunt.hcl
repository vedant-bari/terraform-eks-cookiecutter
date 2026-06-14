locals {
  env = read_terragrunt_config(
    find_in_parent_folders("env.hcl")
  )
}

terraform {
  source = "../../../../modules/iam/policies"
}

iam_role = local.env.locals.execution_role_arn

remote_state {
  backend = "s3"

  config = {
    bucket       = local.env.locals.backend.bucket
    key          = "${local.env.locals.backend.key}/iam/policies/terraform.tfstate"
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
  policies = {
    external_dns = {
      name        = "external-dns-policy"
      description = "Policy for External DNS"

      policy = {
        Version = "2012-10-17"

        Statement = [
          {
            Effect = "Allow"

            Action = [
              "route53:ChangeResourceRecordSets",
              "route53:ListHostedZones",
              "route53:ListResourceRecordSets"
            ]

            Resource = ["*"]
          }
        ]
      }
    }
  }

  tags = {
    Environment = local.env.locals.environment
    ManagedBy   = "Terraform"
  }
}