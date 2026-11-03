include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/gcp-gke/02-modules/07-storage-class"
}

dependency "gke" {
  config_path = "../04-gke"
  mock_outputs = {
    cluster_endpoint       = "0.0.0.0"
    cluster_ca_certificate = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJrekNDQVN3R0F3SUJBZ0lVSk5hbktTVE9hUE5NRE9ra1R2bk15bEFXU2d3d0RRWUpLb1pJemowRUJ3VUZNQ014SVEwS0F3RWlNVEFrQmdOVkJBTVREbk4xYzNSbGMzUXhDekFLQmdOVkJBa01SR0Z5WVhCdWNtVjBhVzl1SUZOMGIzSmxZV1J6TVE4d0NRWURWUVFJREFsdmNtVnlMbU52Ym13d0hoY05NakV3TkRNd01ERTBOVEFlSGhjTk1qRXdORE13TURFMU5UQXdnZ0V3TURJR0ExVUVCaE1DVlZNd0V6QUpCZ05WQkFvVENGSlViM1JsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdpQURBU0NJUXdKS2F2V292Vnphd2R3N3BoWTh0aUdaYklWd0l2VnZEWE1vQWpHcUFxd0ZoUkt1S2dMaGRaYk1WUDBCalV1cWpQY3FEdmNrc0R3S1BhM0QzQUNJQXJ6bU9qQ0FrR0hLd3B2b0lWdz0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="  
  }
}

dependency "vpc" {
  config_path = "../02-vpc"
  mock_outputs = {
    network_name = "default-vpc"
  }
}

locals {
  # Directly access the consolidated storage block exposed from root.hcl
  sc_values = include.root.locals.config.storage
}

inputs = {
  storage_class_name     = local.sc_values.storageClassName
  storage_provisioner    = local.sc_values.storageProvisioner
  tier                   = local.sc_values.tier
  vpc_network_name       = try(dependency.vpc.outputs.network_name, local.sc_values.vpcNetworkName)
  
  # Pass GKE cluster credentials
  cluster_endpoint       = dependency.gke.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.gke.outputs.cluster_ca_certificate
}