# ==============================================================================
# 04-eks: AWS counterpart of gcp-gke/03-modules/04-gke.
#
# - EKS control plane (always multi-AZ), API authentication via access entries
# - Kubernetes secrets envelope-encrypted with a module-managed KMS key
# - One managed node group per entry in node_azs (GCP: one zonal node pool)
# - EKS managed add-ons for AWS-owned components; each add-on that calls AWS
#   APIs gets its own Pod Identity role (no permissions on the node role)
#
# Helm-installed controllers (AWS LB Controller, Cluster Autoscaler, Secrets
# Store CSI + ASCP) live in 09-cluster-addons.
# ==============================================================================

data "aws_partition" "current" {}

locals {
  partition = data.aws_partition.current.partition

  admin_policy_arn = "arn:${local.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_entries = merge(
    var.assume_deploy_role ? {
      deploy-role = {
        principal_arn = var.deploy_role_arn
        policy_associations = {
          admin = {
            policy_arn   = local.admin_policy_arn
            access_scope = { type = "cluster" }
          }
        }
      }
    } : {},
    {
      for arn in var.admin_principal_arns : arn => {
        principal_arn = arn
        policy_associations = {
          admin = {
            policy_arn   = local.admin_policy_arn
            access_scope = { type = "cluster" }
          }
        }
      }
    }
  )

  # Pod Identity roles for AWS-owned add-ons: service account and the AWS
  # managed policies they need (paths under arn:<partition>:iam::aws:policy/).
  # Policy names are static so for_each keys are known at plan time.
  pod_identity_roles = merge(
    {
      vpc-cni = {
        service_account = "aws-node"
        policies        = ["AmazonEKS_CNI_Policy"]
      }
      ebs-csi = {
        service_account = "ebs-csi-controller-sa"
        policies        = ["service-role/AmazonEBSCSIDriverPolicy"]
      }
      efs-csi = {
        service_account = "efs-csi-controller-sa"
        policies        = ["service-role/AmazonEFSCSIDriverPolicy"]
      }
    },
    var.container_insights_enabled ? {
      cloudwatch = {
        service_account = "cloudwatch-agent"
        policies        = ["CloudWatchAgentServerPolicy", "AWSXrayWriteOnlyAccess"]
      }
    } : {}
  )

  pod_identity_policy_attachments = merge([
    for role, cfg in local.pod_identity_roles : {
      for policy in cfg.policies : "${role}/${basename(policy)}" => { role = role, policy = policy }
    }
  ]...)

  vpc_cni_config = {
    env = merge(
      { ENABLE_PREFIX_DELEGATION = tostring(var.prefix_delegation) },
      var.prefix_delegation ? { WARM_PREFIX_TARGET = "1" } : {}
    )
    enableNetworkPolicy = tostring(var.network_policy_enabled)
  }

  addon_settings = merge(
    {
      # Must be running before nodes join so pods get IPs from the start
      # and the max-pods setting matches prefix delegation.
      vpc-cni = {
        before_compute       = true
        configuration_values = jsonencode(local.vpc_cni_config)
        pod_identity_role    = "vpc-cni"
      }
      eks-pod-identity-agent = {
        before_compute = true
      }
      coredns        = {}
      kube-proxy     = {}
      metrics-server = {} # GKE ships metrics-server built in; HPA needs it
      aws-ebs-csi-driver = {
        configuration_values = jsonencode({ controller = { extraVolumeTags = var.resource_tags } })
        pod_identity_role    = "ebs-csi"
      }
      aws-efs-csi-driver = {
        pod_identity_role = "efs-csi"
      }
      # Secrets Store CSI driver + AWS provider (ASCP), the counterpart of the
      # GKE Secret Manager add-on. No role of its own: each app pod reads its
      # secrets with its own Pod Identity (usePodIdentity in the SecretProviderClass).
      aws-secrets-store-csi-driver-provider = {}
    },
    var.container_insights_enabled ? {
      amazon-cloudwatch-observability = {
        pod_identity_role = "cloudwatch"
      }
    } : {}
  )

  addons = {
    for name, s in local.addon_settings : name => {
      before_compute       = try(s.before_compute, false)
      addon_version        = lookup(var.addon_versions, name, "") != "" ? var.addon_versions[name] : null
      most_recent          = false
      configuration_values = try(s.configuration_values, null)
      pod_identity_association = try(s.pod_identity_role, null) == null ? null : [{
        role_arn        = aws_iam_role.pod_identity[s.pod_identity_role].arn
        service_account = local.pod_identity_roles[s.pod_identity_role].service_account
      }]
    }
  }

  # AL2023 nodeadm config. Prefix delegation needs maxPods raised explicitly.
  node_config = <<-EOT
    ---
    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      kubelet:
        config:
          maxPods: ${var.max_pods}
  EOT

  node_groups = {
    for az in var.node_azs : "${var.node_group.name}-${az}" => {
      name       = "${var.node_group.name}-${substr(az, -1, 1)}"
      subnet_ids = [var.private_subnet_ids_by_az[az]]

      ami_type       = var.node_group.ami_type
      instance_types = var.node_group.instance_types
      capacity_type  = var.node_group.capacity_type

      min_size     = var.node_group.min_size
      max_size     = var.node_group.max_size
      desired_size = var.node_group.desired_size

      # "" = follow the latest AMI release for the Kubernetes version, so nodes
      # roll to new AMIs like GKE node auto-upgrade. Pin to stop that.
      ami_release_version            = var.node_group.ami_release_version != "" ? var.node_group.ami_release_version : null
      use_latest_ami_release_version = var.node_group.ami_release_version == ""

      labels = var.node_group.labels

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = var.node_group.disk_size_gb
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      cloudinit_pre_nodeadm = [{
        content_type = "application/node.eks.aws"
        content      = local.node_config
      }]

      update_config      = { max_unavailable = var.node_group.max_unavailable }
      node_repair_config = { enabled = true }

      # The CNI policy lives on the vpc-cni Pod Identity role instead.
      iam_role_attach_cni_policy = false
      iam_role_additional_policies = {
        ssm = "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  upgrade_policy      = { support_type = var.upgrade_support_type }
  deletion_protection = var.deletion_protection

  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnet_ids
  control_plane_subnet_ids = var.private_subnet_ids
  service_ipv4_cidr        = var.service_ipv4_cidr

  endpoint_public_access       = !var.endpoint_private_only
  endpoint_private_access      = true
  endpoint_public_access_cidrs = var.endpoint_private_only ? null : var.endpoint_public_access_cidrs

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = !var.assume_deploy_role
  access_entries                           = local.access_entries

  enable_irsa = var.enable_irsa

  # Kubernetes secrets are envelope-encrypted with a module-created KMS key
  # (rotation on); the encryption_config default enables this.
  enabled_log_types                      = var.control_plane_log_types
  cloudwatch_log_group_retention_in_days = var.control_plane_log_retention_days

  addons = local.addons

  eks_managed_node_groups = local.node_groups
}

# ------------------------------------------------------------------------------
# Pod Identity roles for AWS-owned add-ons
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "pod_identity" {
  for_each = local.pod_identity_roles

  name               = "${var.cluster_name}-${each.key}"
  description        = "Pod Identity role for ${each.value.service_account} on ${var.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy_attachment" "pod_identity" {
  for_each = local.pod_identity_policy_attachments

  role       = aws_iam_role.pod_identity[each.value.role].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/${each.value.policy}"
}
