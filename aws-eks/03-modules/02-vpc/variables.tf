variable "name" {
  description = "Name of the VPC"
  type        = string
}
variable "cidr" {
  description = "CIDR block for a new VPC"
  type        = string
  default     = ""
}
variable "azs" {
  description = "Availability Zones for a new VPC"
  type        = list(string)
  default     = []
}
variable "private_subnets" {
  description = "Private subnet CIDRs for a new VPC"
  type        = list(string)
  default     = []
}
variable "public_subnets" {
  description = "Public subnet CIDRs for a new VPC"
  type        = list(string)
  default     = []
}
variable "database_subnets" {
  description = "Database subnet CIDRs"
  type        = list(string)
  default     = []
}
variable "create_database_subnet_group" {
  description = "Create database subnet group"
  type        = bool
  default     = false
}
variable "create_database_subnet_route_table" {
  description = "Create database subnet route table"
  type        = bool
  default     = false
}
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = true
}
variable "single_nat_gateway" {
  description = "Use one shared NAT Gateway (lower cost, lower AZ resilience)"
  type        = bool
  default     = true
}
variable "enable_dns_hostnames" {
  type    = bool
  default = true
}
variable "enable_dns_support" {
  type    = bool
  default = true
}
variable "public_subnet_tags" {
  type    = map(string)
  default = {}
}
variable "private_subnet_tags" {
  type    = map(string)
  default = {}
}
variable "database_subnet_tags" {
  type    = map(string)
  default = {}
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "vpc_tags" {
  type    = map(string)
  default = {}
}
variable "map_public_ip_on_launch" {
  type    = bool
  default = false
}
variable "create_vpc" {
  description = "Create a new VPC; otherwise use existing_vpc_id and supplied subnet IDs."
  type        = bool
  default     = true
}
variable "existing_vpc_id" {
  description = "Existing VPC ID when create_vpc is false."
  type        = string
  default     = ""
}
variable "existing_private_subnet_ids" {
  description = "Existing private subnet IDs when create_vpc is false."
  type        = list(string)
  default     = []
}
variable "existing_public_subnet_ids" {
  description = "Existing public subnet IDs when create_vpc is false."
  type        = list(string)
  default     = []
}
variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch Logs for a newly created VPC."
  type        = bool
  default     = true
}
variable "flow_logs_retention_days" {
  description = "CloudWatch log retention in days for VPC Flow Logs."
  type        = number
  default     = 30
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_logs_retention_days)
    error_message = "Choose a supported CloudWatch Logs retention period."
  }
}
