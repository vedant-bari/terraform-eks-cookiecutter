# This Terragrunt configuration deploys the GKE cluster for client-a in the dev environment.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# This module depends on the VPC being created first.
dependency "vpc" {
  config_path = "../02-vpc"
  # Ensure the VPC module is applied before this one.
  # This also makes the VPC module's outputs available here.
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_self_link    = "projects/mock-project/global/networks/mock-vpc"
    subnets_self_links = {
      "gke-subnet" = "projects/mock-project/regions/mock-region/subnetworks/mock-gke-subnet"
    }
  }
}

terraform {
  source = "../../../../../02-modules/04-gke"
}

inputs = {
  project_id       = include.root.locals.config.gcp.project_id
  region           = include.root.locals.config.gcp.region
  cluster_name     = include.root.locals.config.gke.cluster_name
  cluster_version  = include.root.locals.config.gke.cluster_version
  network_self_link = dependency.vpc.outputs.vpc_self_link
  subnetwork_self_link = dependency.vpc.outputs.subnets_self_links["gke-subnet"]
  ip_allocation_policy = {
    cluster_secondary_range_name  = include.root.locals.config.vpc.subnets[0].secondary_ip_range[0].range_name # Assuming gke-subnet is the first and has secondary ranges
    services_secondary_range_name = include.root.locals.config.vpc.subnets[0].secondary_ip_range[1].range_name
  }
  logging_service    = include.root.locals.config.gke.logging_service
  monitoring_service = include.root.locals.config.gke.monitoring_service
  cluster_addons     = include.root.locals.config.gke.cluster_addons
  node_pools         = include.root.locals.config.gke.node_pools
  labels             = include.root.locals.config.gcp.tags
}