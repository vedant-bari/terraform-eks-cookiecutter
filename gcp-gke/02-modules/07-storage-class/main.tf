terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0.0"
    }
  }
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${var.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}

resource "kubernetes_storage_class_v1" "custom_filestore" {
  metadata {
    name = var.storage_class_name
  }

  storage_provisioner    = var.storage_provisioner
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = true

  parameters = {
    tier    = var.tier
    network = var.vpc_network_name
  }
}