include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/aws-eks/03-modules/01-bootstrap"
}

locals {
  bootstrap = include.root.locals.config.bootstrap
}

inputs = {
  account_id        = include.root.locals.config.aws.account_id
  state_bucket_name = local.bootstrap.state_bucket_name

  force_destroy                     = try(local.bootstrap.force_destroy, false)
  noncurrent_versions_to_keep       = try(local.bootstrap.noncurrent_versions_to_keep, 5)
  kms_key_arn                       = try(local.bootstrap.kms_key_arn, "")
  account_ebs_encryption_by_default = try(local.bootstrap.account_ebs_encryption_by_default, true)

  deploy_role_name                         = local.bootstrap.deploy_role_name
  deploy_role_trusted_principal_arns       = try(local.bootstrap.deploy_role.trusted_principal_arns, [])
  deploy_role_managed_policy_arns          = try(local.bootstrap.deploy_role.managed_policy_arns, ["arn:aws:iam::aws:policy/AdministratorAccess"])
  deploy_role_max_session_duration_seconds = try(local.bootstrap.deploy_role.max_session_duration_seconds, 3600)
}
