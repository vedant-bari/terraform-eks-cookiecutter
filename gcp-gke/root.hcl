locals {
  config = yamldecode(file("${get_repo_root()}/gcp-gke/12-platform-config/clients/client-a/infra/dev.yaml"))
}

remote_state {
  backend = "gcs"
  config = {
    project = local.config.gcp.project_id
    bucket  = local.config.bootstrap.state_bucket_name
    prefix  = "clients/${local.config.client.name}/${local.config.environment}/${path_relative_to_include()}"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "google" {
  project = "${local.config.gcp.project_id}"
  region  = "${local.config.gcp.region}"
}
EOF
}