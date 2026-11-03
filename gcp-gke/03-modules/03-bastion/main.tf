module "bastion" {
  source  = "terraform-google-modules/bastion-host/google"
  version = "~> 9.0"

  project       = var.project_id
  region        = var.region
  zone          = var.zone
  network       = var.vpc_self_link
  subnet        = var.subnet_self_link
  
  name          = var.bastion_name
  machine_type  = var.machine_type
  disk_size_gb  = var.disk_size_gb
  disk_type     = "pd-standard"

  # Ensure NO external public IP is assigned (Secure IAP Tunneling only)
  external_ip   = false

  labels        = var.tags
}