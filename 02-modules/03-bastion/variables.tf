variable "create_bastion" {
  description = "Whether to create the bastion host and its supporting resources"
  type        = bool
  default     = false
}

variable "project_name" {
  description = "Project name used in resource names"
  type        = string
}

variable "environment" {
  description = "Environment name used in resource names"
  type        = string
}

variable "tags" {
  description = "Tags to apply to bastion resources"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "ID of the existing VPC where the bastion security group is created"
  type        = string
}

variable "public_subnet_id" {
  description = "ID of a public subnet in the existing VPC for the bastion host"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type for the bastion host"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "Optional AMI ID. When null, the latest Amazon Linux 2023 x86_64 AMI is used."
  type        = string
  default     = null
}

variable "existing_role_arn" {
  description = "Optional IAM role ARN to attach through a new instance profile. The role must trust EC2 and include SSM permissions."
  type        = string
  default     = ""
}

variable "bastion_username" {
  description = "Linux user created only when bastion_password is set"
  type        = string
  default     = "ec2-user"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.bastion_username))
    error_message = "bastion_username must be a valid lowercase Linux username."
  }
}

variable "bastion_password" {
  description = "Optional password for bastion_username. Prefer SSM Session Manager instead of SSH passwords."
  type        = string
  default     = null
  sensitive   = true
}

variable "root_volume_size" {
  description = "Size, in GiB, of the encrypted gp3 root volume"
  type        = number
  default     = 20
}

variable "detailed_monitoring" {
  description = "Enable one-minute CloudWatch EC2 metrics"
  type        = bool
  default     = false
}

variable "ingress_rules" {
  description = "List of ingress rules for the bastion security group"
  type = list(object({
    description = optional(string, "SSH Inbound")
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      description = "SSH from anywhere"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

variable "egress_rules" {
  description = "List of egress rules for the bastion security group"
  type = list(object({
    description = optional(string, "Allow all outbound")
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      description = "Allow all outbound"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}
