# ===========================================================
#               ***   VPC Configuration   ***
# ===========================================================
resource "aws_vpc" "finishline_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.managed_by
  }
}
# ===========================================================
#          ***   Internet Gateway Configuration   ***
# ===========================================================
resource "aws_internet_gateway" "finishline_igw" {
  vpc_id = aws_vpc.finishline_vpc.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.managed_by
  }
}
# ===========================================================
#          ***   NAT Gateway Configuration   ***
# ===========================================================
resource "aws_eip" "finishline_eip" {
  count  = length(var.public_subnets_cidr)
  domain = "vpc"
}
# ===========================================================
#          ***   NAT Gateway Configuration   ***
# ===========================================================
resource "aws_nat_gateway" "finishline_nat_gw" {
  count = length(var.public_subnets_cidr)

  subnet_id         = aws_subnet.finishline_public_subnet[count.index].id
  allocation_id     = aws_eip.finishline_eip[count.index].id
  availability_mode = "zonal"

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-gw-${count.index + 1}"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.managed_by
  }
}
# ===========================================================
#          ***   Public Subnet Configuration   ***
# ===========================================================
locals {
  karpenter_tags = var.enable_karpenter_discovery && var.karpenter_cluster_name != "" ? {
    "karpenter.sh/discovery" = var.karpenter_cluster_name
  } : {}
}

resource "aws_subnet" "finishline_public_subnet" {
  count = length(var.public_subnets_cidr)

  vpc_id                  = aws_vpc.finishline_vpc.id
  cidr_block              = var.public_subnets_cidr[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-public-subnet-${count.index + 1}"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.managed_by
    Type        = "public"
  }, local.karpenter_tags)
}
resource "aws_route_table" "finishline_public_rt" {
  vpc_id = aws_vpc.finishline_vpc.id
  tags = {
    Name        = "${var.project_name}-${var.environment}-public-rt"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.managed_by
  }
}
resource "aws_route" "finishline_public_route" {
  route_table_id         = aws_route_table.finishline_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.finishline_igw.id
}
resource "aws_route_table_association" "finishline_public_rta" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = aws_subnet.finishline_public_subnet[count.index].id
  route_table_id = aws_route_table.finishline_public_rt.id
}
# ===========================================================
#          ***   Private Subnet Configuration   ***
# ===========================================================
resource "aws_subnet" "finishline_private_subnet" {
  count = length(var.private_subnets_cidr)

  vpc_id                  = aws_vpc.finishline_vpc.id
  cidr_block              = var.private_subnets_cidr[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge({
    Name        = "${var.project_name}-${var.environment}-private-subnet-${count.index + 1}"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.managed_by
    Type        = "private"
  }, local.karpenter_tags)
}
resource "aws_route_table" "finishline_private_rt" {
  vpc_id = aws_vpc.finishline_vpc.id
  tags = {
    Name        = "${var.project_name}-${var.environment}-private-rt"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.managed_by
  }
}
resource "aws_route" "finishline_private_route" {
  route_table_id         = aws_route_table.finishline_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.finishline_nat_gw[0].id
}
resource "aws_route_table_association" "finishline_private_rta" {
  count          = length(var.private_subnets_cidr)
  subnet_id      = aws_subnet.finishline_private_subnet[count.index].id
  route_table_id = aws_route_table.finishline_private_rt.id
}
# ===========================================================
#          ***   Network ACL Configuration   ***
# ===========================================================
resource "aws_network_acl" "finishline_public_nacl" {
  vpc_id     = aws_vpc.finishline_vpc.id
  subnet_ids = aws_subnet.finishline_public_subnet[*].id

  dynamic "ingress" {
    for_each = var.ingress_rules_transform
    content {
      rule_no    = ingress.value.rule_no
      from_port  = ingress.value.from_port
      to_port    = ingress.value.to_port
      protocol   = ingress.value.protocol
      action     = ingress.value.action
      cidr_block = ingress.value.cidr_block
    }
  }

  dynamic "egress" {
    for_each = var.egress_rules_transform
    content {
      rule_no    = egress.value.rule_no
      from_port  = egress.value.from_port
      to_port    = egress.value.to_port
      protocol   = egress.value.protocol
      action     = egress.value.action
      cidr_block = egress.value.cidr_block
    }
  }
}

resource "aws_network_acl_association" "finishline_public_nacl_assoc" {
  count          = length(var.public_subnets_cidr)
  network_acl_id = aws_network_acl.finishline_public_nacl.id
  subnet_id      = aws_subnet.finishline_public_subnet[count.index].id
}
# ===========================================================
#          ***   VPC Endpoints Configuration   ***
# ===========================================================
resource "aws_security_group" "vpc_endpoints" {
  count = (var.create_eks_endpoint || var.create_sts_endpoint || var.create_ec2_endpoint) ? 1 : 0

  name        = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
  description = "Security group for VPC interface endpoints"
  vpc_id      = aws_vpc.finishline_vpc.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.computed_tags, {
    Name        = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.managed_by
  })
}

resource "aws_vpc_endpoint" "eks_endpoint" {
  count = var.create_eks_endpoint ? 1 : 0

  vpc_id              = aws_vpc.finishline_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.eks"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.finishline_private_subnet[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.computed_tags, {
    Name        = "${var.project_name}-${var.environment}-eks-endpoint"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.managed_by
  })
}

resource "aws_vpc_endpoint" "sts" {
  count = var.create_sts_endpoint ? 1 : 0

  vpc_id              = aws_vpc.finishline_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.finishline_private_subnet[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.computed_tags, {
    Name        = "${var.project_name}-${var.environment}-sts-endpoint"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.managed_by
  })
}

resource "aws_vpc_endpoint" "ec2" {
  count = var.create_ec2_endpoint ? 1 : 0

  vpc_id              = aws_vpc.finishline_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.finishline_private_subnet[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.computed_tags, {
    Name        = "${var.project_name}-${var.environment}-ec2-endpoint"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.managed_by
  })
}

resource "aws_vpc_endpoint" "s3" {
  count = var.create_s3_endpoint ? 1 : 0

  vpc_id            = aws_vpc.finishline_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.finishline_public_rt.id, aws_route_table.finishline_private_rt.id]

  tags = merge(var.computed_tags, {
    Name        = "${var.project_name}-${var.environment}-s3-endpoint"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = var.managed_by
  })
}
