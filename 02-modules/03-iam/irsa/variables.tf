variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider_url" {
  type = string
}

variable "roles" {
  type = map(object({
    role_name      = string
    namespace      = string
    service_account = string
    policy_arns    = list(string)
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}