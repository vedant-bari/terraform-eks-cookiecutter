# GCP exposed debug_apps_map / debug_jenkins_apps, which printed secret seed
# values and Git credentials in plain text. Only non-sensitive facts are output.

output "apps" {
  description = "Deployed apps: namespace, release, image and service account."
  value = {
    for k, v in local.processed_apps_map : k => {
      namespace       = local.app_namespace[k]
      release         = local.app_release[k]
      image           = "${v.image.repository}:${try(v.image.tag, "latest")}"
      service_account = try(v.serviceAccount.name, "")
    }
  }
}

output "app_role_arns" {
  description = "Pod Identity role ARN per app."
  value       = { for k, v in aws_iam_role.app : k => v.arn }
}

output "secret_names" {
  description = "Secrets Manager names per app (values are never output)."
  value       = { for k, v in local.secret_name : k => values(v) if length(v) > 0 }
}

output "jenkins_jobs" {
  description = "Jenkins pipeline job name per app."
  value       = { for k, v in local.jenkins_apps : k => try(v.jenkinsPipeline.jobName, "${k}-pipeline") }
}
