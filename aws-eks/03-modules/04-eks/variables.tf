# ------------------------------------------------------------------------------
# Cluster
# ------------------------------------------------------------------------------

variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes minor version, e.g. \"1.35\". Upgrades are explicit bumps of this value (see the upgrade runbook)."

  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.kubernetes_version))
    error_message = "kubernetes_version must be a minor version such as \"1.35\"."
  }
}

variable "upgrade_support_type" {
  type        = string
  description = "STANDARD: EKS upgrades the control plane itself when standard support ends (no extended-support charge). EXTENDED: stay on the version for 12 more months at extra cost."
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "EXTENDED"], var.upgrade_support_type)
    error_message = "upgrade_support_type must be STANDARD or EXTENDED."
  }
}

variable "deletion_protection" {
  type        = bool
  description = "Block cluster deletion. false matches GCP (deletion_protection = false)."
  default     = false
}

variable "service_ipv4_cidr" {
  type        = string
  description = "Kubernetes service CIDR (GCP services secondary range). Must not overlap the VPC."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID from 01-network."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets for the control-plane ENIs (all AZs)."
}

variable "private_subnet_ids_by_az" {
  type        = map(string)
  description = "Map of AZ to private subnet ID from 01-network."
}

# ------------------------------------------------------------------------------
# Endpoint access (class-B toggles; defaults = GCP parity: public, open)
# ------------------------------------------------------------------------------

variable "endpoint_public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the public API endpoint. [\"0.0.0.0/0\"] matches GCP (no master authorized networks)."
  default     = ["0.0.0.0/0"]
}

variable "endpoint_private_only" {
  type        = bool
  description = "Turn the public endpoint off. Requires a path into the VPC (SSM bastion, VPN) for kubectl and for Terraform layers that talk to the cluster."
  default     = false
}

# ------------------------------------------------------------------------------
# Access
# ------------------------------------------------------------------------------

variable "assume_deploy_role" {
  type        = bool
  description = "Whether Terraform runs as the deploy role (aws.assume_deploy_role). If true the deploy role gets an explicit cluster-admin access entry; if false the identity running Terraform gets creator admin."
}

variable "deploy_role_arn" {
  type        = string
  description = "ARN of the deploy role created by 00-bootstrap."
}

variable "admin_principal_arns" {
  type        = list(string)
  description = "Extra IAM principals (users or roles) given cluster admin through access entries. For SSO roles use the role ARN without the aws-reserved/sso.amazonaws.com/ path."
  default     = []
}

variable "enable_irsa" {
  type        = bool
  description = "Create the IAM OIDC provider for IRSA. Not needed while every workload uses Pod Identity."
  default     = false
}

# ------------------------------------------------------------------------------
# Logging
# ------------------------------------------------------------------------------

variable "control_plane_log_types" {
  type        = list(string)
  description = "Control-plane log types sent to CloudWatch Logs (stand-in for GKE default system logging)."
  default     = ["api", "audit", "authenticator"]
}

variable "control_plane_log_retention_days" {
  type        = number
  description = "Retention of the control-plane CloudWatch log group."
  default     = 7
}

# ------------------------------------------------------------------------------
# Nodes
# ------------------------------------------------------------------------------

variable "node_azs" {
  type        = list(string)
  description = "AZs that get a managed node group (one group per AZ). One AZ matches GCP; list more for multi-AZ (class B)."

  validation {
    condition     = length(var.node_azs) >= 1
    error_message = "node_azs needs at least one AZ."
  }

  validation {
    condition     = alltrue([for az in var.node_azs : contains(keys(var.private_subnet_ids_by_az), az)])
    error_message = "Every node AZ must be one of the VPC AZs (vpc.azs)."
  }
}

variable "node_group" {
  type = object({
    name                = string
    instance_types      = list(string)
    ami_type            = string
    capacity_type       = string
    disk_size_gb        = number
    min_size            = number
    max_size            = number
    desired_size        = number
    max_unavailable     = number
    ami_release_version = string
    labels              = map(string)
  })
  description = "Settings applied to the node group in each node AZ. min/max/desired are per group."

  validation {
    condition     = var.node_group.min_size <= var.node_group.desired_size && var.node_group.desired_size <= var.node_group.max_size
    error_message = "node_group sizes must satisfy min_size <= desired_size <= max_size."
  }
}

variable "max_pods" {
  type        = number
  description = "kubelet maxPods. 110 needs VPC CNI prefix delegation; without it m7i.large fits 29."
  default     = 110
}

# ------------------------------------------------------------------------------
# Add-ons
# ------------------------------------------------------------------------------

variable "prefix_delegation" {
  type        = bool
  description = "VPC CNI prefix delegation (/28 prefixes per ENI slot), raising pod density to max_pods."
  default     = true
}

variable "network_policy_enabled" {
  type        = bool
  description = "Class-B toggle. Turn on the VPC CNI network policy agent. false matches GCP (no NetworkPolicy enforcement)."
  default     = false
}

variable "container_insights_enabled" {
  type        = bool
  description = "Class-B toggle. Install the amazon-cloudwatch-observability add-on (Container Insights, billed per metric/log)."
  default     = false
}

variable "addon_versions" {
  type        = map(string)
  description = "Pinned EKS add-on versions keyed by add-on name. \"\" or missing = the AWS default version for kubernetes_version at creation time (not the newest). List versions with: aws eks describe-addon-versions --kubernetes-version <v> --addon-name <name>."
  default     = {}
}

variable "resource_tags" {
  type        = map(string)
  description = "Tags the EBS CSI driver puts on volumes it creates (resources created from inside the cluster do not get provider default_tags)."
  default     = {}
}
