variable "cluster_name" { type = string }
variable "cluster_version" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "cluster_addons" { type = any }
variable "tags" { type = map(string) }
variable "node_groups" {
  description = "Map of managed node group definitions."
  type        = any
}
variable "cluster_enabled_log_types" {
  description = "EKS control plane log types."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}
variable "create_cloudwatch_log_group" {
  description = "Create the EKS control-plane CloudWatch log group."
  type        = bool
  default     = true
}
variable "cloudwatch_log_group_retention_in_days" {
  description = "Retention for EKS control-plane logs."
  type        = number
  default     = 30
}
variable "cluster_endpoint_private_access" {
  description = "Enable private access to the Kubernetes API endpoint."
  type        = bool
  default     = true
}
variable "cluster_endpoint_public_access" {
  description = "Enable public access to the Kubernetes API endpoint."
  type        = bool
  default     = false
}
variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR allowlist for the public Kubernetes API endpoint."
  type        = list(string)
  default     = []
  validation {
    condition     = !var.cluster_endpoint_public_access || length(var.cluster_endpoint_public_access_cidrs) > 0
    error_message = "When public EKS endpoint access is enabled, provide an explicit CIDR allowlist."
  }
}
