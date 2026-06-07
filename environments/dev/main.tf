


module "networking" {
  source = "../../modules/networking"

  project_name = local.config.project.name
  environment  = local.config.project.environment

  network = local.config.network
}