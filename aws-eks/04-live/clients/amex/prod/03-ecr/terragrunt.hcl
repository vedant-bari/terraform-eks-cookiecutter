include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/aws-eks/03-modules/11-ecr"
}

# No dependency on 02-eks: nodes pull with AmazonEC2ContainerRegistryReadOnly
# on the node role, so ECR needs nothing from the cluster (GCP needed the node
# service account for the reader binding).

locals {
  cfg = include.root.locals.config
  ecr = try(local.cfg.ecr, {})

  # One repository per app image: every apps/*.yaml with ecr.enabled (the AWS
  # name for GCP's artifactRegistry.enabled) contributes basename(image.repository).
  apps_dir  = "${get_repo_root()}/aws-eks/01-config/clients/${local.cfg.client}/${local.cfg.environment}/apps"
  app_files = try(fileset(local.apps_dir, "*.yaml"), [])
  app_images = [
    for f in local.app_files : basename(yamldecode(file("${local.apps_dir}/${f}")).image.repository)
    if try(yamldecode(file("${local.apps_dir}/${f}")).apps.enabled, true) == true
    && try(yamldecode(file("${local.apps_dir}/${f}")).ecr.enabled, false) == true
  ]
}

inputs = {
  repository_namespace = local.cfg.name_prefix
  repositories         = sort(distinct(concat(local.app_images, try(local.ecr.additional_repositories, []))))

  image_tag_mutability = try(local.ecr.image_tag_mutability, "MUTABLE")
  scan_on_push         = try(local.ecr.scan_on_push, true)
  force_delete         = try(local.ecr.force_delete, true)
  kms_key_arn          = try(local.ecr.kms_key_arn, "")
  keep_last_images     = try(local.ecr.lifecycle.keep_last_images, 30)
  untagged_expire_days = try(local.ecr.lifecycle.untagged_expire_days, 7)
}
