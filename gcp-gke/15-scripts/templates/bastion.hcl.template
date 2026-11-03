include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/gcp-gke/02-modules/03-bastion"
}

dependency "vpc" {
  config_path = "../02-vpc"

  # UPDATED MOCK OUTPUTS
  mock_outputs = {
    network_name      = "client-a-dev-vpc"
    network_self_link = "projects/eks-terraform/global/networks/client-a-dev-vpc"
    subnet_name       = "dev-gke-subnet"
    subnet_self_link  = "projects/eks-terraform/regions/asia-south1/subnetworks/dev-gke-subnet"
  }
}
inputs = {
  project_id       = include.root.locals.config.gcp.project_id
  region           = include.root.locals.config.gcp.region
  zone             = include.root.locals.config.gcp.zone
  
  bastion_name     = include.root.locals.config.bastion.name
  machine_type     = include.root.locals.config.bastion.machine_type
  disk_size_gb     = include.root.locals.config.bastion.disk_size_gb
  
  # Bind dynamic outputs from the VPC module dependency
  vpc_self_link    = dependency.vpc.outputs.network_self_link
  subnet_self_link = dependency.vpc.outputs.subnet_self_link
  
  tags             = include.root.locals.config.gcp.tags
}

