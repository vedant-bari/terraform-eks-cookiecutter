include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/gcp-gke/02-modules/06-app-deploy"
}

dependency "gke" {
  config_path = "../04-gke"
  mock_outputs = {
    cluster_endpoint       = "0.0.0.0"
    cluster_ca_certificate = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJrekNDQVN3R0F3SUJBZ0lVSk5hbktTVE9hUE5NRE9ra1R2bk15bEFXU2d3d0RRWUpLb1pJemowRUJ3VUZNQ014SVEwS0F3RWlNVEFrQmdOVkJBTVREbk4xYzNSbGMzUXhDekFLQmdOVkJBa01SR0Z5WVhCdWNtVjBhVzl1SUZOMGIzSmxZV1J6TVE4d0NRWURWUVFJREFsdmNtVnlMbU52Ym13d0hoY05NakV3TkRNd01ERTBOVEFlSGhjTk1qRXdORE13TURFMU5UQXdnZ0V3TURJR0ExVUVCaE1DVlZNd0V6QUpCZ05WQkFvVENGSlViM1JsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdpQURBU0NJUXdKS2F2V292Vnphd2R3N3BoWTh0aUdaYklWd0l2VnZEWE1vQWpHcUFxd0ZoUkt1S2dMaGRaYk1WUDBCalV1cWpQY3FEdmNrc0R3S1BhM0QzQUNJQXJ6bU9qQ0FrR0hLd3B2b0lWdz0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="  
  }
}

locals {
  client_name = include.root.locals.config.client.name
  env_name    = include.root.locals.config.environment

  # Environment-specific apps path: 
  # e.g., 12-platform-config/clients/hdfc-bank/prod/apps
  apps_dir    = "${get_repo_root()}/gcp-gke/12-platform-config/clients/${local.client_name}/${local.env_name}/apps"
  
  # Safely handle fileset using try() in case the apps directory doesn't exist yet
  app_files   = try(fileset(local.apps_dir, "*.yaml"), [])

  # Encode each decoded YAML map into a JSON string to satisfy map(string) typing
  apps = {
    for f in local.app_files : 
    replace(replace(f, "-values.yaml", ""), ".yaml", "") => jsonencode(yamldecode(file("${local.apps_dir}/${f}")))
  }
}

inputs = {
  project_id             = include.root.locals.config.gcp.project_id
  chart_path             = "${get_repo_root()}/gcp-gke/13-helm-charts-app/generic-app"
  
  apps                   = local.apps

  cluster_endpoint       = dependency.gke.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.gke.outputs.cluster_ca_certificate
}