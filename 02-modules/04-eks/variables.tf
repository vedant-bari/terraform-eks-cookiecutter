variable "cluster_name" { type = string }
variable "cluster_version" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "cluster_addons" { type = any }
variable "tags" { type = map(string) }

# NEW: The Node Group map
variable "node_groups" {
  description = "Map of EKS managed node group definitions to create"
  type        = any
}

# NEW: Control Plane Logging
variable "cluster_enabled_log_types" {
  description = "A list of the desired control plane logs to enable."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "create_cloudwatch_log_group" {
  description = "Determines whether a log group is created by this module for the cluster logs."
  type        = bool
  default     = true
}