variable "cluster_name" {
  description = "Name of the EKS cluster where the logging stack is installed."
  type        = string
}

variable "namespace" {
  description = "Existing Kubernetes namespace used by the monitoring and logging stack."
  type        = string
  default     = "monitoring"
}

variable "loki_chart_version" {
  description = "Pinned Grafana Loki Helm chart version."
  type        = string
}

variable "alloy_chart_version" {
  description = "Pinned Grafana Alloy Helm chart version."
  type        = string
}

variable "loki_values" {
  description = "Rendered Loki Helm values loaded by Terragrunt from the configured platform override file."
  type        = string
  sensitive   = true
}

variable "alloy_values" {
  description = "Rendered Alloy Helm values loaded by Terragrunt from the configured platform override file."
  type        = string
  sensitive   = true
}
