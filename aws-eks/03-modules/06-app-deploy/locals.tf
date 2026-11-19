locals {
  # Decode JSON and ONLY keep apps where apps.enabled is true (defaults to true if omitted)
  apps_map = {
    for k, json_str in var.apps : k => jsondecode(json_str)
    if try(jsondecode(json_str).apps.enabled, true) == true
  }

  app_namespace = { for k, v in local.apps_map : k => try(v.namespace.name, try(v.releaseName, k)) }
  app_release   = { for k, v in local.apps_map : k => try(v.releaseName, k) }

  # Full Secrets Manager name per app secret: <client>/<env>/<release>/<secretId>.
  secret_name = {
    for k, v in local.apps_map : k => {
      for s in(try(v.secretsManager.enabled, false) ? v.secretsManager.secrets : []) :
      s.secretId => "${var.client}/${var.environment}/${local.app_release[k]}/${s.secretId}"
    }
  }

  # Inject the ECR repository URL when ecr.enabled (GCP: Artifact Registry path)
  # and the full secret names for the SecretProviderClass.
  processed_apps_map = {
    for k, app_vals in local.apps_map : k => merge(app_vals, {
      image = merge(app_vals.image, {
        repository = try(app_vals.ecr.enabled, false) == true ? "${var.ecr_registry_url}/${var.ecr_repository_namespace}/${basename(app_vals.image.repository)}" : app_vals.image.repository
      })
      },
      try(app_vals.secretsManager.enabled, false) ? {
        secretsManager = merge(app_vals.secretsManager, {
          secrets = [for s in app_vals.secretsManager.secrets : merge(s, { secretName = local.secret_name[k][s.secretId] })]
        })
    } : {})
  }

  # What the chart receives. Secret seed values and Jenkins credentials are
  # dropped: the chart never uses them, and on GCP they ended up stored in the
  # Helm release (readable by anyone who can read Secrets in the namespace).
  helm_values = {
    for k, v in local.processed_apps_map : k => merge(
      { for key, val in v : key => val if key != "jenkinsPipeline" },
      try(v.secretsManager.enabled, false) ? {
        secretsManager = merge(v.secretsManager, {
          secrets = [for s in v.secretsManager.secrets : { for sk, sv in s : sk => sv if sk != "secretValue" }]
        })
      } : {}
    )
  }

  # Every app with a service account gets an IAM role through Pod Identity
  # (GCP: a Google service account through Workload Identity).
  apps_with_identity = {
    for k, v in local.processed_apps_map : k => v
    if try(v.serviceAccount.name, "") != ""
  }

  apps_with_ecr = {
    for k, v in local.processed_apps_map : k => v
    if try(v.ecr.enabled, false) == true
  }

  jenkins_apps = {
    for k, app_vals in local.processed_apps_map : k => app_vals
    if try(app_vals.jenkinsPipeline.enabled, false) == true
  }

  all_secrets = flatten([
    for app_key, app_vals in local.processed_apps_map : [
      for secret in try(app_vals.secretsManager.enabled, false) ? app_vals.secretsManager.secrets : [] : {
        key    = "${app_key}-${secret.secretId}"
        app    = app_key
        name   = secret.secretName
        value  = secret.secretValue
        has_sa = try(app_vals.serviceAccount.name, "") != ""
      }
    ]
  ])
  secrets_map = { for s in local.all_secrets : s.key => s }

  # Extract, normalize, and globally deduplicate credentials across all apps by their ID
  jenkins_secrets_map = {
    for s in flatten([
      for app_key, app_vals in local.jenkins_apps : concat(
        try(app_vals.jenkinsPipeline.githubToken, "") != "" ? [{
          id   = try(app_vals.jenkinsPipeline.githubCredentialsId, "${app_key}-github")
          type = "secretText"
          data = { text = app_vals.jenkinsPipeline.githubToken }
        }] : [],
        [
          for cred in try(app_vals.jenkinsPipeline.credentials, []) : {
            id   = cred.id
            type = cred.type
            data = cred.type == "secretText" ? { text = try(cred.secretValue, "") } : {
              username = try(cred.username, "")
              password = try(cred.password, cred.secretValue, "")
            }
          }
        ]
      )
    ]) : lower(replace(s.id, "_", "-")) => s
  }
}
