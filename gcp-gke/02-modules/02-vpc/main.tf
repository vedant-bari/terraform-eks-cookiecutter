module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.0"

  project_id   = var.project_id
  network_name = var.vpc_name
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name               = var.subnet_name
      subnet_ip                 = var.subnet_cidr
      subnet_region             = var.region
      subnet_private_access     = true
      
      # Now pulling dynamic values from module variables
      subnet_flow_logs          = var.flow_logs
      subnet_flow_logs_interval = var.flow_logs_interval
      subnet_flow_logs_sampling = var.flow_logs_sampling
      subnet_flow_logs_metadata = var.flow_logs_metadata
    }
  ]

  secondary_ranges = {
    (var.subnet_name) = [
      {
        range_name    = var.pod_range_name
        ip_cidr_range = var.pod_range_cidr
      },
      {
        range_name    = var.svc_range_name
        ip_cidr_range = var.svc_range_cidr
      }
    ]
  }
}

# Cloud Router & NAT for Outbound Internet Access
resource "google_compute_router" "router" {
  name    = "${var.vpc_name}-router"
  region  = var.region
  project = var.project_id
  network = module.vpc.network_id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.vpc_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}