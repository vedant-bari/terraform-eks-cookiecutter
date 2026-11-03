include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/gcp-gke/02-modules/01-bootstrap"
}

inputs = {
  project_id                  = include.root.locals.config.gcp.project_id
  state_bucket_name           = include.root.locals.config.bootstrap.state_bucket_name
  region                      = include.root.locals.config.gcp.region
  uniform_bucket_level_access = try(include.root.locals.config.bootstrap.uniform_bucket_level_access, true)
  force_destroy               = try(include.root.locals.config.bootstrap.force_destroy, false)
  tags                        = include.root.locals.config.gcp.tags
}


