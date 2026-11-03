include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/gcp-gke/02-modules/02-vpc"
}

inputs = {
  project_id         = include.root.locals.config.gcp.project_id
  region             = include.root.locals.config.gcp.region
  
  vpc_name           = include.root.locals.config.vpc.vpc_name
  subnet_name        = include.root.locals.config.vpc.subnet_name
  subnet_cidr        = include.root.locals.config.vpc.subnet_cidr
  pod_range_name     = include.root.locals.config.vpc.pod_range_name
  pod_range_cidr     = include.root.locals.config.vpc.pod_range_cidr
  svc_range_name     = include.root.locals.config.vpc.svc_range_name
  svc_range_cidr     = include.root.locals.config.vpc.svc_range_cidr

  # Flow logs mapped from YAML with graceful fallbacks
  flow_logs          = try(include.root.locals.config.vpc.flow_logs, true)
  flow_logs_interval = try(include.root.locals.config.vpc.flow_logs_interval, "INTERVAL_5_SEC")
  flow_logs_sampling = try(include.root.locals.config.vpc.flow_logs_sampling, 0.5)
  flow_logs_metadata = try(include.root.locals.config.vpc.flow_logs_metadata, "INCLUDE_ALL_METADATA")
}