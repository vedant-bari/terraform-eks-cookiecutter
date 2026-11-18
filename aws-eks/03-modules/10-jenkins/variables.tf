variable "yaml_path" {
  description = "Path to the Jenkins Helm values template (01-config/.../jenkins/<env>.yaml)."
  type        = string
}

variable "chart_version" {
  description = "Jenkins Helm chart version (https://charts.jenkins.io)."
  type        = string
  default     = "5.10.0"
}

variable "namespace" {
  description = "Namespace for Jenkins and its agents. The values file and JCasC refer to it as \"jenkins\"."
  type        = string
  default     = "jenkins"
}

variable "agent_service_account" {
  description = "Kubernetes service account the agent pods run as (controller.agentKubernetesProfile.serviceAccount in the values)."
  type        = string
  default     = "jenkins-agent"
}

variable "storage_class" {
  description = "StorageClass for JENKINS_HOME: the EFS RWX class (GCP parity) or the gp3 block class."
  type        = string
}

variable "access_mode" {
  description = "PVC access mode matching storage_class: ReadWriteMany for EFS, ReadWriteOnce for gp3."
  type        = string

  validation {
    condition     = contains(["ReadWriteMany", "ReadWriteOnce"], var.access_mode)
    error_message = "access_mode must be ReadWriteMany or ReadWriteOnce."
  }
}

variable "ecr_repository_namespace" {
  description = "ECR repository prefix (<client>-<env>). The agent role can push only to <namespace>/* (GCP granted project-wide writer)."
  type        = string
}

variable "cluster_wide_rbac" {
  description = "Class-B toggle. true (GCP parity) binds a ClusterRole that lets agents patch workloads in every namespace. false keeps only the per-namespace Roles created by 08-applications."
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "EKS cluster name from 02-eks."
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS API endpoint from 02-eks (also the Jenkins Kubernetes cloud serverUrl)."
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Base64 cluster CA from 02-eks (also the Jenkins Kubernetes cloud serverCertificate)."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile for aws eks get-token (\"\" = default credential chain)."
  type        = string
  default     = ""
}

variable "kube_role_arn" {
  description = "Role that aws eks get-token assumes (the deploy role). \"\" = caller identity."
  type        = string
  default     = ""
}
