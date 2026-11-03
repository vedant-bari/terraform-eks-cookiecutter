include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/gcp-gke/02-modules/02-vpc"
}

inputs = {
  project_id     = include.root.locals.config.gcp.project_id
  region         = include.root.locals.config.gcp.region
  
  create_vpc     = include.root.locals.config.vpc.create
  vpc_name       = include.root.locals.config.vpc.vpc_name
  subnet_name    = include.root.locals.config.vpc.subnet_name
  subnet_cidr    = include.root.locals.config.vpc.subnet_cidr
  pod_range_name = include.root.locals.config.vpc.pod_range_name
  pod_range_cidr = include.root.locals.config.vpc.pod_range_cidr
  svc_range_name = include.root.locals.config.vpc.svc_range_name
  svc_range_cidr = include.root.locals.config.vpc.svc_range_cidr
}