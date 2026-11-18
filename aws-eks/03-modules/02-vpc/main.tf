# ==============================================================================
# 02-vpc: AWS counterpart of gcp-gke/03-modules/02-vpc.
#
# GCP has one regional subnet with secondary ranges for pods and services.
# AWS subnets are bound to one AZ and VPC CNI gives pods IPs from the node
# subnets, so this creates one private (nodes + pods) and one public (ALB + NAT)
# subnet per AZ. Nodes are private behind NAT (deliberate deviation from GCP).
# ==============================================================================

locals {
  # Flow-log bucket names are global, so include the account ID.
  flow_logs_bucket_name = "${var.name_prefix}-vpc-flow-logs-${var.account_id}"

  # Every field available up to flow-log format v5; the AWS equivalent of
  # GCP INCLUDE_ALL_METADATA.
  flow_log_format = join(" ", [
    "$${version}", "$${account-id}", "$${interface-id}", "$${srcaddr}", "$${dstaddr}",
    "$${srcport}", "$${dstport}", "$${protocol}", "$${packets}", "$${bytes}",
    "$${start}", "$${end}", "$${action}", "$${log-status}", "$${vpc-id}",
    "$${subnet-id}", "$${instance-id}", "$${tcp-flags}", "$${type}",
    "$${pkt-srcaddr}", "$${pkt-dstaddr}", "$${region}", "$${az-id}",
    "$${sublocation-type}", "$${sublocation-id}", "$${pkt-src-aws-service}",
    "$${pkt-dst-aws-service}", "$${flow-direction}", "$${traffic-path}",
  ])
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.vpc_name
  cidr = var.vpc_cidr
  azs  = var.azs

  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Nodes never get public IPs; public subnets only carry ALBs and NAT.
  map_public_ip_on_launch = false

  enable_nat_gateway     = true
  single_nat_gateway     = !var.nat_gateway_per_az
  one_nat_gateway_per_az = var.nat_gateway_per_az

  # Strip all rules from the default security group (nothing should use it).
  manage_default_security_group = true

  # Subnet discovery for the AWS Load Balancer Controller (Phase 4).
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  enable_flow_log                   = var.flow_logs_enabled
  flow_log_destination_type         = "s3"
  flow_log_destination_arn          = var.flow_logs_enabled ? aws_s3_bucket.flow_logs[0].arn : ""
  flow_log_traffic_type             = var.flow_logs_traffic_type
  flow_log_max_aggregation_interval = var.flow_logs_max_aggregation_interval
  flow_log_log_format               = local.flow_log_format
  flow_log_file_format              = "plain-text"
  flow_log_per_hour_partition       = true

  # The delivery policy must exist before AWS validates the destination.
  depends_on = [aws_s3_bucket_policy.flow_logs]
}

# ------------------------------------------------------------------------------
# Flow-log bucket (S3 is about 10x cheaper than CloudWatch Logs for flow logs).
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "flow_logs" {
  count = var.flow_logs_enabled ? 1 : 0

  bucket        = local.flow_logs_bucket_name
  force_destroy = var.flow_logs_force_destroy
}

resource "aws_s3_bucket_ownership_controls" "flow_logs" {
  count  = var.flow_logs_enabled ? 1 : 0
  bucket = aws_s3_bucket.flow_logs[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "flow_logs" {
  count  = var.flow_logs_enabled ? 1 : 0
  bucket = aws_s3_bucket.flow_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flow_logs" {
  count  = var.flow_logs_enabled ? 1 : 0
  bucket = aws_s3_bucket.flow_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "flow_logs" {
  count  = var.flow_logs_enabled ? 1 : 0
  bucket = aws_s3_bucket.flow_logs[0].id

  rule {
    id     = "expire-flow-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.flow_logs_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "flow_logs" {
  count = var.flow_logs_enabled ? 1 : 0

  statement {
    sid       = "AWSLogDeliveryWrite"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.flow_logs[0].arn}/AWSLogs/${var.account_id}/*"]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${var.region}:${var.account_id}:*"]
    }
  }

  statement {
    sid       = "AWSLogDeliveryAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.flow_logs[0].arn]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${var.region}:${var.account_id}:*"]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.flow_logs[0].arn,
      "${aws_s3_bucket.flow_logs[0].arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "flow_logs" {
  count  = var.flow_logs_enabled ? 1 : 0
  bucket = aws_s3_bucket.flow_logs[0].id
  policy = data.aws_iam_policy_document.flow_logs[0].json

  depends_on = [aws_s3_bucket_public_access_block.flow_logs]
}

# ------------------------------------------------------------------------------
# VPC endpoints
# ------------------------------------------------------------------------------

# Free gateway endpoint: S3 traffic (ECR layers, state, flow logs) bypasses NAT.
resource "aws_vpc_endpoint" "s3" {
  count = var.s3_gateway_endpoint ? 1 : 0

  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids)

  tags = {
    Name = "${var.vpc_name}-s3"
  }
}

# Class-B toggle: interface endpoints keep AWS API traffic off the NAT gateway
# and are required if the cluster later goes private-only.
resource "aws_security_group" "vpc_endpoints" {
  count = var.interface_endpoints_enabled ? 1 : 0

  name        = "${var.vpc_name}-vpc-endpoints"
  description = "HTTPS from inside the VPC to interface endpoints"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${var.vpc_name}-vpc-endpoints"
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_https" {
  count = var.interface_endpoints_enabled ? 1 : 0

  security_group_id = aws_security_group.vpc_endpoints[0].id
  description       = "HTTPS from the VPC"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = module.vpc.vpc_cidr_block
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.interface_endpoints_enabled ? toset(var.interface_endpoint_services) : toset([])

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name = "${var.vpc_name}-${replace(each.value, ".", "-")}"
  }
}
