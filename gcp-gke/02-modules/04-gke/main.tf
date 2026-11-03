module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "~> 40.0"

  project_id                 = var.project_id
  name                       = var.cluster_name
  region                     = var.region
  zones                      = [var.zone]
  
  network                    = var.vpc_name
  subnetwork                 = var.subnet_name
  
  # IP Allocation Policy (VPC-Native)
  ip_range_pods              = var.pod_range_name
  ip_range_services          = var.svc_range_name
  
  # Cluster Version & Release Channel
  kubernetes_version         = var.cluster_version
  release_channel            = var.release_channel
  deletion_protection        = var.delete_protection
  
  remove_default_node_pool   = true
  
  # Security Addons
  identity_namespace          = var.workload_identity_enabled ? "enabled" : null
  enable_secret_manager_addon = var.secret_manager_enabled

  # Core Addons
  http_load_balancing        = var.cluster_addons.http_load_balancing
  horizontal_pod_autoscaling = var.cluster_addons.horizontal_pod_autoscaling
  filestore_csi_driver       = var.enable_filestore_csi

  # Node Pools Configuration mapped from YAML
  node_pools = [
    {
      name              = "${var.cluster_name}-node-pool"
      machine_type      = var.machine_type
      node_count        = var.node_count
      min_count         = var.enable_autoscaling ? var.min_nodes : null
      max_count         = var.enable_autoscaling ? var.max_nodes : null
      disk_size_gb      = var.disk_size_gb
      disk_type         = var.disk_type
      auto_upgrade      = true
      auto_repair       = true
    }
  ]

  node_pools_oauth_scopes = {
    all = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  node_pools_labels = {
    all = var.tags
  }
}