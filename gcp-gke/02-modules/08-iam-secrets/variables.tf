variable "project_id" { type = string }
variable "namespace" { type = string }
variable "kubernetes_service_account_name" { type = string }
variable "google_service_account_name" { type = string }

variable "secrets" {
  description = "List of secrets to create in Secret Manager"
  type = list(object({
    secretId    = string
    secretValue = string
    key         = string
  }))
  default = []
}