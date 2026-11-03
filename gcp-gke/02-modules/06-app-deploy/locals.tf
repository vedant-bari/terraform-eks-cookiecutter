locals {
  # Decode JSON and ONLY keep apps where apps.enabled is true (defaults to true if omitted)
  apps_map = {
    for k, json_str in var.apps : k => jsondecode(json_str)
    if try(jsondecode(json_str).apps.enabled, true) == true
  }

  # Automatically inject Google Artifact Registry regional path if artifactRegistry.enabled is true
  processed_apps_map = {
    for k, app_vals in local.apps_map : k => merge(app_vals, {
      image = merge(app_vals.image, {
        repository = try(app_vals.artifactRegistry.enabled, false) == true ? "${var.region}-docker.pkg.dev/${var.project_id}/${try(app_vals.artifactRegistry.repositoryId, "${k}-repo")}/${basename(app_vals.image.repository)}" : app_vals.image.repository
      })
    })
  }

  apps_with_gsa = {
    for k, app_vals in local.processed_apps_map : k => app_vals
    if try(app_vals.serviceAccount.annotations["iam.gke.io/gcp-service-account"], "") != ""
  }

  apps_with_gar = {
    for k, app_vals in local.processed_apps_map : k => app_vals
    if try(app_vals.artifactRegistry.enabled, false) == true
  }

  jenkins_apps = {
    for k, app_vals in local.processed_apps_map : k => app_vals
    if try(app_vals.jenkinsPipeline.enabled, false) == true
  }

  all_secrets = flatten([
    for app_key, app_vals in local.processed_apps_map : [
      for secret in try(app_vals.secretManager.enabled, false) ? app_vals.secretManager.secrets : [] : {
        key       = "${app_key}-${secret.secretId}"
        secret_id = secret.secretId
        value     = secret.secretValue
        gsa_email = try(app_vals.serviceAccount.annotations["iam.gke.io/gcp-service-account"], "")
      }
    ]
  ])
  secrets_map = { for s in local.all_secrets : s.key => s }

  # Extract, normalize, and globally deduplicate credentials across all apps by their ID
  jenkins_secrets_map = {
    for s in flatten([
      for app_key, app_vals in local.jenkins_apps : concat(
        try(app_vals.jenkinsPipeline.githubToken, "") != "" ? [{
          id   = try(app_vals.jenkinsPipeline.githubCredentialsId, "github-vedant-bari")
          type = "secretText"
          data = { text = app_vals.jenkinsPipeline.githubToken }
        }] : [],
        try(app_vals.jenkinsPipeline.dockerhubPassword, "") != "" ? [{
          id   = try(app_vals.jenkinsPipeline.dockerhubCredentialsId, "dockerhub-id")
          type = "usernamePassword"
          data = {
            username = try(app_vals.jenkinsPipeline.dockerhubUsername, "")
            password = app_vals.jenkinsPipeline.dockerhubPassword
          }
        }] : [],
        [
          for cred in try(app_vals.jenkinsPipeline.credentials, []) : {
            id   = cred.id
            type = cred.type
            data = cred.type == "secretText" ? { text = try(cred.secretValue, "") } : {
              username = try(cred.username, "")
              password = try(cred.password, "")
            }
          }
        ]
      )
    ]) : lower(replace(s.id, "_", "-")) => s
  }
}