include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/gcp-gke/02-modules/10-jenkins"
}

dependency "gke" {
  config_path = "../04-gke"
  mock_outputs = {
    cluster_endpoint       = "https://0.0.0.0"
    cluster_ca_certificate = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJrekNDQVN3R0F3SUJBZ0lVSk5hbktTVE9hUE5NRE9ra1R2bk15bEFXU2d3d0RRWUpLb1pJemowRUJ3VUZNQ014SVEwS0F3RWlNVEFrQmdOVkJBTVREbk4xYzNSbGMzUXhDekFLQmdOVkJBa01SR0Z5WVhCdWNtVjBhVzl1SUZOMGIzSmxZV1J6TVE4d0NRWURWUVFJREFsdmNtVnlMbU52Ym13d0hoY05NakV3TkRNd01ERTBOVEFlSGhjTk1qRXdORE13TURFMU5UQXdnZ0V3TURJR0ExVUVCaE1DVlZNd0V6QUpCZ05WQkFvVENGSlViM1JsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdpQURBU0NJUXdKS2F2V292Vnphd2R3N3BoWTh0aUdaYklWd0l2VnZEWE1vQWpHcUFxd0ZoUkt1S2dMaGRaYk1WUDBCalV1cWpQY3FEdmNrc0R3S1BhM0QzQUNJQXJ6bU9qQ0FrR0hLd3B2b0lWdz0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo="  
  }
}

locals {
  client_name = include.root.locals.config.client.name
  env_name    = include.root.locals.config.environment

  jenkins_dir        = "${get_repo_root()}/gcp-gke/12-platform-config/clients/${local.client_name}/${local.env_name}/jenkins"
  yaml_path          = "${local.jenkins_dir}/${local.env_name}.yaml"
  dockerhub_username = "testuser40"
  dockerhub_token    = "your-dockerhub-access-token"
}

inputs = {
  project_id             = include.root.locals.config.gcp.project_id
  yaml_path              = local.yaml_path
  cluster_endpoint       = dependency.gke.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.gke.outputs.cluster_ca_certificate
  dockerhub_username     = local.dockerhub_username
  dockerhub_token        = local.dockerhub_token
}