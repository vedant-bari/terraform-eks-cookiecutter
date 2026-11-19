include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/aws-eks/03-modules/06-app-deploy"
}

locals {
  cfg  = include.root.locals.config
  apps = try(local.cfg.applications, {})

  apps_dir  = "${get_repo_root()}/aws-eks/01-config/clients/${local.cfg.client}/${local.cfg.environment}/apps"
  app_files = try(fileset(local.apps_dir, "*.yaml"), [])

  raw_apps = {
    for f in local.app_files :
    replace(replace(f, "-values.yaml", ""), ".yaml", "") => yamldecode(file("${local.apps_dir}/${f}"))
  }
}

dependency "eks" {
  config_path = "../02-eks"
  mock_outputs = {
    cluster_name                       = local.cfg.eks.cluster_name
    cluster_endpoint                   = "https://00000000000000000000000000000000.gr7.${local.cfg.aws.region}.eks.amazonaws.com"
    cluster_certificate_authority_data = "bW9jaw=="
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "ecr" {
  config_path = "../03-ecr"
  mock_outputs = {
    registry_url         = "${local.cfg.aws.account_id}.dkr.ecr.${local.cfg.aws.region}.amazonaws.com"
    repository_namespace = local.cfg.name_prefix
    repository_urls = {
      for name, app in local.raw_apps : basename(app.image.repository) => "mock" if try(app.ecr.enabled, false)
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "jenkins" {
  config_path = "../07-jenkins"
  mock_outputs = {
    namespace             = "jenkins"
    agent_service_account = "jenkins-agent"
    jenkins_internal_url  = "http://jenkins.jenkins.svc.cluster.local:8080"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# Apps need the EFS StorageClass (04-storage), the ALB controller and the ASCP
# secrets driver (05-cluster-addons / 02-eks).
dependencies {
  paths = ["../04-storage", "../05-cluster-addons"]
}

inputs = {
  apps        = { for name, app in local.raw_apps : name => jsonencode(app) }
  chart_path  = "${get_repo_root()}/aws-eks/05-helm-charts/generic-app"
  client      = local.cfg.client
  environment = local.cfg.environment

  ecr_registry_url         = dependency.ecr.outputs.registry_url
  ecr_repository_namespace = dependency.ecr.outputs.repository_namespace
  ecr_repository_names     = keys(dependency.ecr.outputs.repository_urls)

  secret_recovery_window_in_days = try(local.apps.secrets_manager.recovery_window_in_days, 7)
  secrets_kms_key_arn            = try(local.apps.secrets_manager.kms_key_arn, "")

  jenkins_namespace             = dependency.jenkins.outputs.namespace
  jenkins_agent_service_account = dependency.jenkins.outputs.agent_service_account
  jenkins_url                   = dependency.jenkins.outputs.jenkins_internal_url
  jenkins_sync_image            = try(local.apps.jenkins_sync_image, "python:3.11.18-slim")

  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  region                             = local.cfg.aws.region
  aws_profile                        = local.cfg.aws.profile
  kube_role_arn                      = local.cfg.aws.assume_deploy_role ? local.cfg.bootstrap.deploy_role_arn : ""
}
