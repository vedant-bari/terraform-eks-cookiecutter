# gcp-gke/03-live/clients/hdfc-bank/dev/06-apps/terragrunt.hcl

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
    cluster_name             = "gke-hdfc-bank-dev"
    cluster_endpoint         = "0.0.0.0"
    cluster_ca_certificate = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJrekNDQVN3R0F3SUJBZ0lVSk5hbktTVE9hUE5NRE9ra1R2bk15bEFXU2d3d0RRWUpLb1pJemowRUJ3VUZNQ014SVEwS0F3RWlNVEFrQmdOVkJBTVREbk4xYzNSbGMzUXhDekFLQmdOVkJBa01SR0Z5WVhCdWNtVjBhVzl1SUZOMGIzSmxZV1J6TVE4d0NRWURWUVFJREFsdmNtVnlMbU52Ym13d0hoY05NakV3TkRNd01ERTBOVEFlSGhjTk1qRXdORE13TURFMU5UQXdnZ0V3TURJR0ExVUVCaE1DVlZNd0V6QUpCZ05WQkFvVENGSlViM1JsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdpQURBU0NJUXdKS2F2V292Vnphd2R3N3BoWTh0aUdaYklWd0l2VnZEWE1vQWpHcUFxd0ZoUkt1S2dMaGRaYk1WUDBCalV1cWpQY3FEdmNrc0R3S1BhM0QzQUNJQXJ6bU9qQ0FrR0hLd3B2b0lWdz0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="  
  }
}

dependency "gar" {
  config_path = "../05-artifact-registry"
  mock_outputs = {
    repository_id = "hdfc-bank-dev-repo"
  }
}

dependencies {
  paths = ["../10-jenkins", "../05-artifact-registry"]
}

locals {
  client_name = include.root.locals.config.client.name
  env_name    = include.root.locals.config.environment

  apps_dir    = "${get_repo_root()}/gcp-gke/12-platform-config/clients/${local.client_name}/${local.env_name}/apps"
  app_files   = try(fileset(local.apps_dir, "*.yaml"), [])

  # Decode raw YAML maps safely in locals (no dependency references here)
  raw_apps = {
    for f in local.app_files : 
    replace(replace(f, "-values.yaml", ""), ".yaml", "") => yamldecode(file("${local.apps_dir}/${f}"))
  }
}

inputs = {
  project_id             = include.root.locals.config.gcp.project_id
  region                 = include.root.locals.config.gcp.region
  cluster_name           = dependency.gke.outputs.cluster_name
  chart_path             = "${get_repo_root()}/gcp-gke/13-helm-charts-app/generic-app"
  cluster_endpoint       = dependency.gke.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.gke.outputs.cluster_ca_certificate
  repository_id          = dependency.gar.outputs.repository_id

  # Inject dependency outputs and merge configurations safely inside inputs
  apps = {
    for name, app_config in local.raw_apps : 
    name => jsonencode(
      merge(
        app_config,
        {
          artifactRegistry = merge(
            try(app_config.artifactRegistry, {}),
            {
              createRepo   = false
              repositoryId = dependency.gar.outputs.repository_id
            }
          )
        }
      )
    )
  }
}