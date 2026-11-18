# ------------------------------------------------------------------------------
# Cluster connection (helm provider, exec auth)
# ------------------------------------------------------------------------------

variable "cluster_name" {
  type        = string
  description = "EKS cluster name from 02-eks."
}

variable "cluster_endpoint" {
  type        = string
  description = "EKS API endpoint from 02-eks."
}

variable "cluster_certificate_authority_data" {
  type        = string
  description = "Base64 cluster CA from 02-eks."
}

variable "kubernetes_version" {
  type        = string
  description = "Cluster minor version from 02-eks; the Cluster Autoscaler image must match it."
}

variable "region" {
  type        = string
  description = "AWS region."
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile for aws eks get-token (\"\" = default credential chain)."
  default     = ""
}

variable "kube_role_arn" {
  type        = string
  description = "Role that aws eks get-token assumes (the deploy role). \"\" = caller identity."
  default     = ""
}

variable "vpc_id" {
  type        = string
  description = "VPC ID from 01-network. Passed to the LB controller because IMDSv2 hop limit 1 stops it discovering the VPC itself."
}

variable "namespace" {
  type        = string
  description = "Namespace for both controllers."
  default     = "kube-system"
}

variable "resource_tags" {
  type        = map(string)
  description = "Tags the LB controller puts on every ALB/NLB, target group and security group it creates (they do not get provider default_tags)."
  default     = {}
}

# ------------------------------------------------------------------------------
# AWS Load Balancer Controller (GKE: HTTP load balancing add-on)
# ------------------------------------------------------------------------------

variable "lb_controller" {
  type = object({
    chart_version   = string
    replica_count   = number
    service_account = string
  })
  description = "AWS Load Balancer Controller Helm settings."
}

# ------------------------------------------------------------------------------
# Cluster Autoscaler (GKE: node pool autoscaling)
# ------------------------------------------------------------------------------

variable "cluster_autoscaler" {
  type = object({
    chart_version   = string
    image_tag       = string
    service_account = string
    extra_args      = map(string)
  })
  description = "Cluster Autoscaler Helm settings. image_tag must be the same minor as the cluster."

  validation {
    condition     = startswith(var.cluster_autoscaler.image_tag, "v${var.kubernetes_version}.")
    error_message = "cluster_autoscaler.image_tag must match the cluster minor (v<kubernetes_version>.x). Bump it together with eks.kubernetes_version."
  }
}
