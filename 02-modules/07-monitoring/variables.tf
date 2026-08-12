variable "cluster_name" {
  description = "Name of the EKS cluster where the monitoring stack is installed."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for Prometheus, Grafana, and Alertmanager."
  type        = string
  default     = "monitoring"
}

variable "chart_version" {
  description = "Pinned kube-prometheus-stack chart version."
  type        = string
  default     = "86.0.0"
}

variable "storage_class_name" {
  description = "StorageClass used by Grafana, Prometheus, and Alertmanager persistent volume claims."
  type        = string
}

variable "monitoring_values" {
  description = "kube-prometheus-stack Helm values loaded from the shared client monitoring-and-logging override file."
  type        = string
}
