#################################################
# Environment
#################################################

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

#################################################
# Cluster Configuration
#################################################

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"

  type = string

  default = "1.33"

  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.kubernetes_version))
    error_message = "Kubernetes version must be in the format 1.xx."
  }
}

#################################################
# Networking
#################################################

variable "vpc_id" {
  description = "VPC ID where EKS will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by EKS and node groups"

  type = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least two private subnets must be provided."
  }
}

#################################################
# IAM
#################################################

variable "cluster_role_arn" {
  description = "IAM role ARN used by the EKS control plane"
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN used by EKS managed node groups"
  type        = string
}

#################################################
# Endpoint Access
#################################################

variable "endpoint_public_access" {
  description = "Enable public access to the Kubernetes API server"

  type = bool

  default = true
}

variable "endpoint_private_access" {
  description = "Enable private access to the Kubernetes API server"

  type = bool

  default = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to access the EKS public endpoint"

  type = list(string)

  default = [
    "0.0.0.0/0"
  ]
}

#################################################
# Cluster Logging
#################################################

variable "enabled_cluster_log_types" {
  description = "Control plane logs to enable"

  type = list(string)

  default = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  validation {
    condition = alltrue([
      for log in var.enabled_cluster_log_types :
      contains(
        [
          "api",
          "audit",
          "authenticator",
          "controllerManager",
          "scheduler"
        ],
        log
      )
    ])

    error_message = "Invalid control plane log type specified."
  }
}

#################################################
# System Node Group
#################################################

variable "system_node_group" {
  description = "Configuration for the system node group"

  type = object({
    instance_types = list(string)
    capacity_type  = string
    min_size       = number
    max_size       = number
    desired_size   = number
  })

  default = {
    instance_types = ["t3.medium"]

    capacity_type = "ON_DEMAND"

    min_size     = 2
    max_size     = 4
    desired_size = 2
  }

  validation {
    condition = contains(
      [
        "ON_DEMAND",
        "SPOT"
      ],
      var.system_node_group.capacity_type
    )

    error_message = "System node group capacity_type must be ON_DEMAND or SPOT."
  }
}

#################################################
# Application Node Group
#################################################

variable "application_node_group" {
  description = "Configuration for the application node group"

  type = object({
    instance_types = list(string)
    capacity_type  = string
    min_size       = number
    max_size       = number
    desired_size   = number
  })

  default = {
    instance_types = ["m5.large"]

    capacity_type = "ON_DEMAND"

    min_size     = 2
    max_size     = 5
    desired_size = 3
  }

  validation {
    condition = contains(
      [
        "ON_DEMAND",
        "SPOT"
      ],
      var.application_node_group.capacity_type
    )

    error_message = "Application node group capacity_type must be ON_DEMAND or SPOT."
  }
}

#################################################
# Tags
#################################################

variable "tags" {
  description = "Tags applied to all EKS resources"

  type = map(string)

  default = {}
}