include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_parent_terragrunt_dir()}/../02-modules/03-bastion"
}

dependency "vpc" {
  config_path = "../02-vpc"

  mock_outputs = {
    vpc_id         = "vpc-mock-id"
    public_subnets = ["subnet-mock-id"]
  }
}

inputs = {
  create_bastion    = include.root.locals.config.bastion.create
  existing_role_arn = include.root.locals.config.bastion.existing_role_arn

  project_name = include.root.locals.config.client.name
  environment  = include.root.locals.config.environment
  tags         = include.root.locals.config.eks.tags

  vpc_id = dependency.vpc.outputs.vpc_id

  public_subnet_id = length(dependency.vpc.outputs.public_subnets) > 0 ? dependency.vpc.outputs.public_subnets[0] : ""

  instance_type    = include.root.locals.config.bastion.instance_type
  bastion_username = include.root.locals.config.bastion.username
  bastion_password = include.root.locals.config.bastion.password

  ingress_rules = include.root.locals.config.bastion.ingress_rules
  egress_rules  = include.root.locals.config.bastion.egress_rules
}
