include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/aws-eks/03-modules/01-bootstrap"
}

inputs = {
  bucket_name   = include.root.locals.infra_config.bootstrap.state_bucket_name
  force_destroy = include.root.locals.infra_config.bootstrap.force_destroy
  tags          = include.root.locals.infra_config.aws.tags
}