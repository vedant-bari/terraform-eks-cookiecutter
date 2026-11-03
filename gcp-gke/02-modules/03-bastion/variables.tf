variable "project_id" {
  type        = string
  description = "The Google Cloud project ID where resources will be created."
}

variable "region" {
  type        = string
  description = "The target GCP region for regional resources."
  default     = "asia-south1"
}

variable "zone" {
  type        = string
  description = "The target GCP zone for zone-specific resources."
  default     = "asia-south1-a"
}

variable "vpc_self_link" {
  type        = string
  description = "The self-link URI of the VPC network where resources will be connected."
}

variable "subnet_self_link" {
  type        = string
  description = "The self-link URI of the specific subnet for network placement."
}

variable "bastion_name" {
  type        = string
  description = "The name identifier for the bastion host or compute instance."
  default     = "bastion-host"
}

variable "machine_type" {
  type        = string
  description = "The GCP machine type instance flavor to use."
  default     = "e2-medium"
}

variable "disk_size_gb" {
  type        = number
  description = "The boot disk size for the instance measured in gigabytes."
  default     = 30
}

variable "tags" {
  type        = map(string)
  description = "A key-value map of labels/tags to assign to resources for tracking and management."
  default     = {}
}