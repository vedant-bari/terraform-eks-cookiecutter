variable "storage_class_name" {
  description = "Name of the custom storage class"
  type        = string
}

variable "storage_provisioner" {
  description = "The storage provisioner driver"
  type        = string
}

variable "tier" {
  description = "Filestore tier (e.g., standard, enterprise)"
  type        = string
  default     = "standard"
}

variable "vpc_network_name" {
  description = "The name of the VPC network where GKE and Filestore reside"
  type        = string
}

# Added variables for cluster authentication
variable "cluster_endpoint" {
  description = "The cluster endpoint for the Kubernetes provider"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "The cluster CA certificate for the Kubernetes provider"
  type        = string
}