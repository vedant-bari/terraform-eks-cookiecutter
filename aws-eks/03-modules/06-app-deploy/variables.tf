variable "apps" {
  type        = map(string)
  description = "Map of app name (file name without -values.yaml) to JSON-encoded app values from 01-config/.../apps/*.yaml."
}

variable "chart_path" {
  type        = string
  description = "Local filesystem path to the generic-app Helm chart."
}

variable "client" {
  type        = string
  description = "Client name; first segment of every Secrets Manager secret name."
}

variable "environment" {
  type        = string
  description = "Environment name; second segment of every Secrets Manager secret name."
}

# ------------------------------------------------------------------------------
# ECR (from 03-ecr)
# ------------------------------------------------------------------------------

variable "ecr_registry_url" {
  type        = string
  description = "<account>.dkr.ecr.<region>.amazonaws.com"
}

variable "ecr_repository_namespace" {
  type        = string
  description = "Repository prefix (<client>-<env>); apps with ecr.enabled use <registry>/<namespace>/<basename of image.repository>."
}

variable "ecr_repository_names" {
  type        = list(string)
  description = "Image names 03-ecr created repositories for; every app with ecr.enabled must be in this list."
}

# ------------------------------------------------------------------------------
# Secrets Manager
# ------------------------------------------------------------------------------

variable "secret_recovery_window_in_days" {
  type        = number
  description = "Days a deleted secret can be restored. 0 deletes immediately (GCP behaviour); 7-30 keeps it recoverable, but the same name cannot be recreated until the window ends or the secret is restored."
  default     = 7

  validation {
    condition     = var.secret_recovery_window_in_days == 0 || (var.secret_recovery_window_in_days >= 7 && var.secret_recovery_window_in_days <= 30)
    error_message = "secret_recovery_window_in_days must be 0 or between 7 and 30."
  }
}

variable "secrets_kms_key_arn" {
  type        = string
  description = "\"\" = the AWS managed key (aws/secretsmanager). Set a CMK ARN to encrypt app secrets with it."
  default     = ""
}

# ------------------------------------------------------------------------------
# Jenkins (from 07-jenkins)
# ------------------------------------------------------------------------------

variable "jenkins_namespace" {
  type        = string
  description = "Namespace of the Jenkins controller and agents."
  default     = "jenkins"
}

variable "jenkins_agent_service_account" {
  type        = string
  description = "Service account the Jenkins agents run as; bound to the per-namespace deployer Roles."
  default     = "jenkins-agent"
}

variable "jenkins_url" {
  type        = string
  description = "In-cluster Jenkins URL used by the job sync."
}

variable "jenkins_sync_image" {
  type        = string
  description = "Image for the job-sync Kubernetes Job (runs templates/sync_jenkins.py)."
  default     = "python:3.11.18-slim"
}

# ------------------------------------------------------------------------------
# Cluster connection
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
