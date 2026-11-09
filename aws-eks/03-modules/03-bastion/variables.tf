variable "create_bastion" {
  description = "Whether to create the bastion host and supporting resources."
  type        = bool
  default     = false
}
variable "project_name" { type = string }
variable "environment" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
variable "vpc_id" { type = string }
variable "public_subnet_id" {
  description = "Public subnet ID used when creating a bastion."
  type        = string
  default     = ""
}
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "ami_id" {
  type    = string
  default = null
}
variable "existing_role_arn" {
  type    = string
  default = ""
}
variable "bastion_username" {
  type    = string
  default = "ec2-user"
  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.bastion_username))
    error_message = "bastion_username must be a valid lowercase Linux username."
  }
}
variable "bastion_password" {
  type        = string
  default     = null
  sensitive   = true
  description = "Optional password; prefer SSM Session Manager."
}
variable "root_volume_size" {
  type    = number
  default = 20
}
variable "detailed_monitoring" {
  type    = bool
  default = false
}
variable "associate_public_ip_address" {
  description = "Assign a public IPv4 address to the bastion. Prefer SSM through private connectivity."
  type        = bool
  default     = false
}
variable "ingress_rules" {
  description = "Explicitly approved ingress rules. Empty by default; SSM is preferred."
  type = list(object({
    description = optional(string, "Bastion ingress")
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}
variable "egress_rules" {
  type = list(object({
    description = optional(string, "Allow outbound")
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [{
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }]
}
