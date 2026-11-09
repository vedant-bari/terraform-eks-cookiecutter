variable "project_id" {
  type        = string
  description = "The Google Cloud project ID where the GKE cluster will be created."
}

variable "region" {
  type        = string
  description = "The target GCP region for the regional GKE cluster."
  default     = "asia-south1"
}

variable "zone" {
  type        = string
  description = "The primary target GCP zone (if applicable for zonal control planes)."
  default     = "asia-south1-a"
}

variable "cluster_name" {
  type        = string
  description = "The unique name identifier for the GKE cluster."
  default     = "prod-gke-cluster"
}

variable "cluster_version" {
  type        = string
  description = "The desired Kubernetes version for the GKE cluster nodes and control plane."
  default     = ""
}

variable "release_channel" {
  type        = string
  description = "The GKE release channel (e.g., REGULAR, STABLE, RAPID)."
  default     = "REGULAR"
}

variable "vpc_name" {
  type        = string
  description = "The name of the VPC network where the GKE cluster will be deployed."
  default     = "prod-vpc"
}

variable "subnet_name" {
  type        = string
  description = "The name of the specific subnet within the VPC for the cluster."
  default     = "prod-subnet"
}

variable "pod_range_name" {
  type        = string
  description = "The name of the secondary IP range designated for Kubernetes pods."
  default     = "gke-pod-range"
}

variable "svc_range_name" {
  type        = string
  description = "The name of the secondary IP range designated for Kubernetes services."
  default     = "gke-svc-range"
}

variable "machine_type" {
  type        = string
  description = "The GCP machine type instance flavor for the GKE node pool."
  default     = "e2-medium"
}

variable "node_count" {
  type        = number
  description = "The initial or default number of worker nodes per zone."
  default     = 2
}

variable "disk_size_gb" {
  type        = number
  description = "The boot disk size for each worker node measured in gigabytes."
  default     = 50
}

variable "disk_type" {
  type        = string
  description = "The disk type for node instances (e.g., pd-standard, pd-balanced, pd-ssd)."
  default     = "pd-standard"
}

variable "min_nodes" {
  type        = number
  description = "The minimum number of nodes per zone when autoscaling is enabled."
  default     = 1
}

variable "max_nodes" {
  type        = number
  description = "The maximum number of nodes per zone when autoscaling is enabled."
  default     = 5
}

variable "enable_autoscaling" {
  type        = bool
  description = "Flag to enable or disable node pool autoscaling."
  default     = true
}

variable "delete_protection" {
  type        = bool
  description = "Flag to protect the GKE cluster against accidental deletion via Terraform or CLI."
  default     = true
}

variable "enable_filestore_csi" {
  type        = bool
  description = "Flag to enable the Google Cloud Filestore CSI driver storage plugin."
  default     = true
}

variable "workload_identity_enabled" {
  type        = bool
  description = "Flag to enable Workload Identity for secure pod-to-GCP service authentication."
  default     = true
}

variable "secret_manager_enabled" {
  type        = bool
  description = "Flag to enable Secret Manager integration or related secret CSI features."
  default     = false
}

variable "cluster_addons" {
  type = object({
    http_load_balancing        = bool
    horizontal_pod_autoscaling = bool
    gce_csi_driver             = bool
  })
  description = "Configuration object containing toggles for native GKE cluster addons."
  default = {
    http_load_balancing        = true
    horizontal_pod_autoscaling = true
    gce_csi_driver             = true
  }
}

variable "tags" {
  type        = map(string)
  description = "A key-value map of labels/tags to apply to GKE cluster resources for billing and grouping."
  default     = {}
}