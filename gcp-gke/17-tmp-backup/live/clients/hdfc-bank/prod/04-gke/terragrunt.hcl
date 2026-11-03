include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/gcp-gke/02-modules/04-gke"
}

dependency "vpc" {
  config_path = "../02-vpc"

  mock_outputs = {
    network_name = "client-a-dev-vpc"
    subnet_name  = "dev-gke-subnet"
  }
}

inputs = {
  project_id                = include.root.locals.config.gcp.project_id
  region                    = include.root.locals.config.gcp.region
  zone                      = include.root.locals.config.gcp.zone
  
  cluster_name              = include.root.locals.config.gke.cluster_name
  cluster_version           = include.root.locals.config.gke.cluster_version
  release_channel           = include.root.locals.config.gke.release_channel
  delete_protection         = include.root.locals.config.gke.delete_protection
  
  # FIXED: Match the network_name output exported by the VPC module
  vpc_name                  = dependency.vpc.outputs.network_name
  subnet_name               = dependency.vpc.outputs.subnet_name
  pod_range_name            = include.root.locals.config.vpc.pod_range_name
  svc_range_name            = include.root.locals.config.vpc.svc_range_name
  
  # Node configuration from YAML
  machine_type              = include.root.locals.config.gke.machine_type
  node_count                = include.root.locals.config.gke.node_count
  disk_size_gb              = include.root.locals.config.gke.disk_size_gb
  disk_type                 = try(include.root.locals.config.gke.disk_type, "pd-standard")
  min_nodes                 = include.root.locals.config.gke.min_nodes
  max_nodes                 = include.root.locals.config.gke.max_nodes
  enable_autoscaling        = include.root.locals.config.gke.enable_autoscaling
  
  enable_filestore_csi      = include.root.locals.config.gke.enable_filestore_csi
  
  # Security toggles
  workload_identity_enabled = include.root.locals.config.gke.workloadIdentityEnabled
  secret_manager_enabled    = include.root.locals.config.gke.secretManagerEnabled
  
  cluster_addons            = include.root.locals.config.gke.cluster_addons
  tags                      = include.root.locals.config.gcp.tags
}