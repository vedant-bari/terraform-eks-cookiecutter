resource "aws_vpc_endpoint" "private_s3_gateway" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = module.vpc.private_route_table_ids

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-s3-gateway-endpoint"
    }
  )
}