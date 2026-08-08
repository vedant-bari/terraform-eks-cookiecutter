
# 01-bootstrap/clients/client_a/dev/terragrunt.hcl

terraform {
  # Dynamically resolves the relative path to the repo root
  source = "${get_path_to_repo_root()}/02-modules/01-bootstrap"
}

# Generate a local provider for the bootstrap phase
# (We cannot include the root terragrunt.hcl here because the S3 bucket does not exist yet)
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "ap-south-1"
  
  default_tags {
    tags = {
      Environment = "dev"
      Client      = "client-a"
      ManagedBy   = "Terragrunt-Bootstrap"
    }
  }
}
EOF
}

# Pass the necessary inputs to the 01-bootstrap Terraform module
inputs = {
  environment = "dev"

  bucket_name = "tf-state-client-a"

  kms_alias   = "alias/tf-state-client-a"

  create_lock_table = false

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
    Owner       = "PlatformTeam"
  }
}