include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/gcp-gke/02-modules/08-iam-secrets"
}

# --- ADD THIS DEPENDENCY ---
dependency "gke" {
  config_path = "../04-gke" 
  mock_outputs = {
    cluster_name = "gke-client-a-dev"
  }
}
# ---------------------------

locals {
  app_values = yamldecode(file("${get_repo_root()}/gcp-gke/12-platform-config/clients/client-a/apps/frontend-web-values.yaml"))
}

inputs = {
  project_id                      = local.app_values.gcpProject
  cluster_name                    = dependency.gke.outputs.cluster_name
  namespace                       = local.app_values.namespace.name
  kubernetes_service_account_name = local.app_values.serviceAccount.name
  google_service_account_name     = local.app_values.googleServiceAccountName
  secrets                         = local.app_values.secretManager.secrets
}