# vpc

resource "aws_vpc" "default" {
  count                = var.enabled ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.tags, { Name = "${local.common_tags.Name}-vpc" })
}

# internet gateway

resource "aws_internet_gateway" "default" {
  count  = var.enabled ? 1 : 0
  vpc_id = aws_vpc.default[0].id

  tags = merge(local.tags, { Name = "${local.common_tags.Name}-igw", Component = "igw" })
}

# elastic ip

resource "aws_eip" "nat" {
  count  = var.enabled && var.private_enabled && var.nat_enabled ? length(var.avail_zones) : 0
  domain = "vpc"
}

# subnets

resource "aws_subnet" "public" {
  count                   = var.enabled ? length(var.avail_zones) : 0
  vpc_id                  = aws_vpc.default[0].id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = element(var.avail_zones, count.index)
  map_public_ip_on_launch = true

  tags = merge(local.tags, { Name = "${local.common_tags.Name}-public-subnet-${element(var.avail_zones, count.index)}" })
}

resource "aws_subnet" "private" {
  count                   = var.enabled && var.private_enabled ? length(var.avail_zones) : 0
  vpc_id                  = aws_vpc.default[0].id
  cidr_block              = element(var.private_subnet_cidrs, count.index)
  availability_zone       = element(var.avail_zones, count.index)
  map_public_ip_on_launch = false

  tags = merge(local.tags, { Name = "${local.common_tags.Name}-private-subnet-${element(var.avail_zones, count.index)}" })
}

# nat gateway

resource "aws_nat_gateway" "default" {
  count         = var.enabled && var.private_enabled && var.nat_enabled ? length(var.avail_zones) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.tags, { Name = "${local.common_tags.Name}-natgw-${element(var.avail_zones, count.index)}", Component = "nat" })
}

# routes

resource "aws_route_table" "public" {
  count  = var.enabled ? length(var.avail_zones) : 0
  vpc_id = aws_vpc.default[0].id

  tags = merge(local.tags, { Name = "${local.common_tags.Name}-public-route-table-${element(var.avail_zones, count.index)}" })
}

resource "aws_route_table" "private" {
  count  = var.enabled && var.private_enabled ? length(var.avail_zones) : 0
  vpc_id = aws_vpc.default[0].id

  tags = merge(local.tags, { Name = "${local.common_tags.Name}-private-route-table-${element(var.avail_zones, count.index)}" })
}

resource "aws_route" "public" {
  count                  = var.enabled ? length(var.avail_zones) : 0
  route_table_id         = aws_route_table.public[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default[0].id
}

resource "aws_route" "private" {
  count                  = var.enabled && var.private_enabled && var.nat_enabled ? length(var.avail_zones) : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.default[count.index].id
}

resource "aws_route_table_association" "public" {
  count          = var.enabled ? length(var.avail_zones) : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = var.enabled && var.private_enabled ? length(var.avail_zones) : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# endpoints

resource "aws_security_group" "endpoints" {
  count       = var.enabled && var.private_enabled && var.endpoints_enabled ? 1 : 0
  name        = "${local.common_tags.Name}-endpoints-sg"
  description = "Allow traffic to VPC endpoints"
  vpc_id      = aws_vpc.default[0].id
  tags        = merge(local.tags, { Name = "${local.common_tags.Name}-endpoints-sg" })
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "inbound" {
  count             = var.enabled && var.private_enabled && var.endpoints_enabled ? 1 : 0
  description       = "Inbound traffic from anywhere"
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.endpoints.0.id
}

resource "aws_security_group_rule" "outbound" {
  count             = var.enabled && var.private_enabled && var.endpoints_enabled ? 1 : 0
  description       = "Outbound traffic anywhere"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.endpoints.0.id
}

resource "aws_vpc_endpoint" "s3" {
  count             = var.enabled && var.private_enabled && var.endpoints_enabled ? 1 : 0
  vpc_id            = aws_vpc.default[0].id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private.*.id
}

resource "aws_vpc_endpoint" "ecr-dkr" {
  count               = var.enabled && var.private_enabled && var.endpoints_enabled ? 1 : 0
  vpc_id              = aws_vpc.default[0].id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private.*.id
  security_group_ids  = [aws_security_group.endpoints.0.id]
}

resource "aws_vpc_endpoint" "ecr-api" {
  count               = var.enabled && var.private_enabled && var.endpoints_enabled ? 1 : 0
  vpc_id              = aws_vpc.default[0].id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private.*.id
  security_group_ids  = [aws_security_group.endpoints.0.id]
}
