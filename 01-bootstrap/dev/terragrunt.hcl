terraform {
  source = "../../02-modules/01-bootstrap"
}

iam_role = "arn:aws:iam::111111111111:role/TerraformBootstrapRole"

inputs = {
  environment = "dev"

  bucket_name = "company-dev-terraform-state"

  kms_alias = "alias/dev-terraform"

  create_lock_table = false

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
    Owner       = "PlatformTeam"
  }
}