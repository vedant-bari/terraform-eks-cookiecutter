include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/aws-eks/03-modules/03-bastion"
}

dependency "vpc" {
  config_path = "../01-network"
  mock_outputs = {
    vpc_id = "vpc-00000000000000000"
    public_subnet_ids = ["subnet-00000000000000000"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate"]
}

locals {
  cfg = include.root.locals.config.bastion
  password_env = try(local.cfg.password_env, "BASTION_PASSWORD")
  password = get_env(local.password_env, "")
}

inputs = {
  create_bastion              = try(local.cfg.create, false)
  project_name                = include.root.locals.config.client.name
  environment                 = include.root.locals.config.environment
  vpc_id                      = dependency.vpc.outputs.vpc_id
  public_subnet_id            = try(dependency.vpc.outputs.public_subnet_ids[0], "")
  instance_type               = try(local.cfg.instance_type, "t3.micro")
  existing_role_arn           = try(local.cfg.existing_role_arn, "")
  bastion_username            = try(local.cfg.username, "ec2-user")
  bastion_password            = local.password != "" ? local.password : null
  associate_public_ip_address = try(local.cfg.associate_public_ip_address, false)
  ingress_rules               = try(local.cfg.ingress_rules, [])
  egress_rules                = try(local.cfg.egress_rules, [])
  tags                        = include.root.locals.tags
}
