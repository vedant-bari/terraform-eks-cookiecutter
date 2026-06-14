locals {
  environment = "dev"

  backend = {
    bucket = "company-dev-tf-state"
    key    = "dev"
    region = "us-east-1"
  }

  execution_role_arn = "arn:aws:iam::111111111111:role/TerraformExecutionRole"

  vpc = {
    name = "vpc-dev"

    cidr = "10.0.0.0/16"

    azs = [
      "us-east-1a",
      "us-east-1b"
    ]

    private_subnets = [
      "10.0.1.0/24",
      "10.0.2.0/24"
    ]

    public_subnets = [
      "10.0.101.0/24",
      "10.0.102.0/24"
    ]

    database_subnets = [
      "10.0.151.0/24",
      "10.0.152.0/24"
    ]
  }

  
}