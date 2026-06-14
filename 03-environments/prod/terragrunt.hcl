# live/prod/terragrunt.hcl

terraform {
  source = "../../environments"
}

remote_state {
  backend = "s3"

  config = {
    bucket       = local.env.locals.state_bucket
    key          = local.env.locals.state_key
    region       = local.env.locals.aws_region
    encrypt      = true
    use_lockfile = true
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}


inputs = {
  environment         = "prod"

  vpc_cidr            = "10.0.0.0/16"

  availability_zones  = [
    "ap-south-1a",
    "ap-south-1b"
  ]

  public_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  private_subnets = [
    "10.0.11.0/24",
    "10.0.12.0/24"
  ]

  cluster_name        = "dev-eks"
  cluster_version     = "1.33"

  node_instance_type  = "t3.medium"

  desired_size        = 2
  min_size            = 1
  max_size            = 3
}