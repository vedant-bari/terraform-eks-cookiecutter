variable "account_id" {
  type        = string
  description = "AWS account ID. Used to scope the flow-log bucket policy and to make the bucket name globally unique."

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

variable "region" {
  type        = string
  description = "AWS region. Used for VPC endpoint service names and to check that every AZ belongs to it."
}

variable "name_prefix" {
  type        = string
  description = "<client>-<env>, used to derive resource names."
}

variable "vpc_name" {
  type        = string
  description = "Name tag of the VPC."
}

variable "vpc_cidr" {
  type        = string
  description = "Primary IPv4 CIDR of the VPC."

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "azs" {
  type        = list(string)
  description = "Availability zones the VPC spans. EKS needs at least two, even when nodes run in one."

  validation {
    condition     = length(var.azs) >= 2
    error_message = "EKS requires subnets in at least two availability zones."
  }

  validation {
    condition     = alltrue([for az in var.azs : startswith(az, var.region)])
    error_message = "Every entry in azs must belong to var.region."
  }
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "One private subnet per AZ, in azs order. Nodes and pods live here; with VPC CNI prefix delegation each node takes /28 prefixes, so size these at /19 or larger."

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.azs)
    error_message = "private_subnet_cidrs must have one entry per AZ."
  }
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "One public subnet per AZ, in azs order. Only internet-facing ALBs and the NAT gateway live here."

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.azs)
    error_message = "public_subnet_cidrs must have one entry per AZ."
  }
}

variable "nat_gateway_per_az" {
  type        = bool
  description = "Class-B toggle. false (default) = one shared NAT gateway; true = one per AZ for AZ-independent egress."
  default     = false
}

variable "flow_logs_enabled" {
  type        = bool
  description = "Enable VPC flow logs, delivered to a dedicated S3 bucket."
  default     = true
}

variable "flow_logs_traffic_type" {
  type        = string
  description = "ACCEPT, REJECT or ALL."
  default     = "ALL"

  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_logs_traffic_type)
    error_message = "flow_logs_traffic_type must be ACCEPT, REJECT or ALL."
  }
}

variable "flow_logs_max_aggregation_interval" {
  type        = number
  description = "Seconds. AWS allows 60 or 600; 60 is the closest to the GCP 5-second interval."
  default     = 60

  validation {
    condition     = contains([60, 600], var.flow_logs_max_aggregation_interval)
    error_message = "flow_logs_max_aggregation_interval must be 60 or 600."
  }
}

variable "flow_logs_retention_days" {
  type        = number
  description = "Days before flow-log objects expire from the S3 bucket."
  default     = 30
}

variable "flow_logs_force_destroy" {
  type        = bool
  description = "Let terraform destroy delete the flow-log bucket even when it still holds logs. true matches GCP, where flow logs disappear with the VPC."
  default     = true
}

variable "s3_gateway_endpoint" {
  type        = bool
  description = "Create the free S3 gateway endpoint (ECR image layers and state traffic skip the NAT gateway). Stand-in for Private Google Access."
  default     = true
}

variable "interface_endpoints_enabled" {
  type        = bool
  description = "Class-B toggle. Create interface endpoints for interface_endpoint_services in the private subnets (billed per endpoint per AZ)."
  default     = false
}

variable "interface_endpoint_services" {
  type        = list(string)
  description = "Service suffixes for interface endpoints, e.g. ecr.api, ecr.dkr, sts, secretsmanager, logs."
  default     = ["ecr.api", "ecr.dkr", "sts", "secretsmanager", "logs"]
}
