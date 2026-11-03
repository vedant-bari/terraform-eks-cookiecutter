variable "project_id" {
  type        = string
  description = "The GCP project ID where the VPC and subnets will be created."
}

variable "region" {
  type        = string
  description = "The GCP region for the subnetwork and Cloud Router."
}

variable "vpc_name" {
  type        = string
  description = "The name of the custom VPC network."
}

variable "subnet_name" {
  type        = string
  description = "The name of the primary subnetwork."
}

variable "subnet_cidr" {
  type        = string
  description = "The primary CIDR block for the subnetwork nodes."
}

variable "pod_range_name" {
  type        = string
  description = "The name of the secondary IP range assigned to GKE pods."
}

variable "pod_range_cidr" {
  type        = string
  description = "The CIDR block for the GKE pod secondary range."
}

variable "svc_range_name" {
  type        = string
  description = "The name of the secondary IP range assigned to GKE services."
}

variable "svc_range_cidr" {
  type        = string
  description = "The CIDR block for the GKE service secondary range."
}
# Flow Logs Variables
variable "flow_logs" {
  type    = bool
  default = true
}

variable "flow_logs_interval" {
  type    = string
  default = "INTERVAL_5_SEC"
}

variable "flow_logs_sampling" {
  type    = number
  default = 0.5
}

variable "flow_logs_metadata" {
  type    = string
  default = "INCLUDE_ALL_METADATA"
}
