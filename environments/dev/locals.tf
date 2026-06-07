locals {
  config = yamldecode(
    file("${path.root}/../../platform-config/platform.yaml")
  )
}