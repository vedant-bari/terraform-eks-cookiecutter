variable "cluster_name" {
  description = "EKS cluster that hosts the application releases."
  type        = string
}
variable "chart_path" {
  description = "Path to the shared generic application Helm chart."
  type        = string
}
variable "apps" {
  description = "Map of Helm release names to application chart values."
  type        = map(any)
  default     = {}
}
