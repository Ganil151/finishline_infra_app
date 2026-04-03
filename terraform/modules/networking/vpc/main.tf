#========================================================================
#                     *** Virtual Private Cloud ***
#========================================================================
locals {
  karpenter_tags = var.enable_karpenter_discovery && var.karpenter_cluster_name != "" ? {
    "karpenter.sh/discovery" = var.karpenter_cluster_name
  } : {}

  endpoint_ingress_rules = [1]
  endpoint_egress_rules  = [1]
}
resource "aws_vpc" "finishline_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames
  instance_tenancy     = var.instance_tenancy

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc"
  })

}
#========================================================================
#                  *** Internet Gateway Configuration ***
#========================================================================
resource "aws_internet_gateway" "finishline_igw" {
  vpc_id = aws_vpc.finishline_vpc.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-igw"
  })

}
#========================================================================
#                  *** Elastic IP ***
#========================================================================
resource "aws_eip" "finishline_eip" {
  count  = length(var.public_subnets_cidr)
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-eip-${count.index + 1}"
  })
}
#========================================================================
#                  *** Public Subnet Configuration ***
#========================================================================
resource "aws_subnet" "finishline_public_subnet" {
  count = length(var.public_subnets_cidr)

  vpc_id                  = aws_vpc.finishline_vpc.id
  cidr_block              = var.public_subnets_cidr[count.index]
  availability_zone       = var.public_subnets_az[count.index]
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-subnet-${count.index + 1}"
    Type = "public"
  }, local.karpenter_tags)
}

#========================================================================
#                  *** NAT Gateway Configuration ***
#========================================================================
resource "aws_nat_gateway" "finishline_nat_gateway" {
  count             = length(var.public_subnets_cidr)
  subnet_id         = aws_subnet.finishline_public_subnet[count.index].id
  allocation_id     = aws_eip.finishline_eip[count.index].id
  availability_mode = "zonal"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-gateway-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.finishline_igw]
}
#_______________________*** Public Route Table ***_________________________
resource "aws_route_table" "finishline_public_route_table" {
  vpc_id = aws_vpc.finishline_vpc.id
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-rt"
  })

}
#_______________________*** Public Route  ***______________________________
resource "aws_route" "finishline_public_route" {
  route_table_id         = aws_route_table.finishline_public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.finishline_igw.id
}
#______________________*** Public Route Association *** ___________________
resource "aws_route_table_association" "finishline_public_route_association" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = aws_subnet.finishline_public_subnet[count.index].id
  route_table_id = aws_route_table.finishline_public_route_table.id
}
#========================================================================
#                  *** Private Subnet Configuration ***
#========================================================================
resource "aws_subnet" "finishline_private_subnet" {
  count                   = length(var.private_subnets_cidr)
  vpc_id                  = aws_vpc.finishline_vpc.id
  cidr_block              = var.private_subnets_cidr[count.index]
  availability_zone       = var.private_subnets_az[count.index]
  map_public_ip_on_launch = var.map_private_ip_on_launch

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-subnet-${count.index + 1}"
    Type = "private"
  }, local.karpenter_tags)
}
#_______________________*** Private Route Table ***________________________
resource "aws_route_table" "finishline_private_route_table" {
  count  = length(var.private_subnets_cidr)
  vpc_id = aws_vpc.finishline_vpc.id
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-rt-${count.index + 1}"
  })

}
#_______________________*** Private NAT Routes ***_________________________
resource "aws_route" "finishline_private_nat_route" {
  count                  = length(var.private_subnets_cidr)
  route_table_id         = aws_route_table.finishline_private_route_table[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.finishline_nat_gateway[count.index].id
}
#______________________*** Private Route Association *** _________________
resource "aws_route_table_association" "finishline_private_route_association" {
  count          = length(var.private_subnets_cidr)
  subnet_id      = aws_subnet.finishline_private_subnet[count.index].id
  route_table_id = aws_route_table.finishline_private_route_table[count.index].id
}
#========================================================================
#                  *** Network ACL Configuration ***
#========================================================================
resource "aws_network_acl" "finishline_network_acl" {
  vpc_id     = aws_vpc.finishline_vpc.id
  subnet_ids = concat(aws_subnet.finishline_public_subnet[*].id, aws_subnet.finishline_private_subnet[*].id)
  dynamic "ingress" {
    for_each = var.network_acl_ingress_rules
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
    for_each = var.network_acl_egress_rules

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
#______________________*** Network ACL Association *** _________________
resource "aws_network_acl_association" "finishline_public_nacl_association" {
  count          = length(var.public_subnets_cidr)
  network_acl_id = aws_network_acl.finishline_network_acl.id
  subnet_id      = aws_subnet.finishline_public_subnet[count.index].id
}
#========================================================================
#                  *** VPC Endpoints Configuration ***
#========================================================================
resource "aws_security_group" "finishline_vpc_endpoints_sg" {
  description = "Security group for VPC endpoints"
  count       = (var.create_eks_endpoints || var.create_sts_endpoint || var.create_ec2_endpoint) ? 1 : 0
  name        = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
  vpc_id      = aws_vpc.finishline_vpc.id

  dynamic "ingress" {
    for_each = local.endpoint_ingress_rules

    content {
      description = "HTTPS from VPC"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
    }

  }

  dynamic "egress" {
    for_each = local.endpoint_egress_rules
    content {
      description = "Allow all outbound"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
  })

}
#___________________________*** EKS Endpoints *** ________________________
resource "aws_vpc_endpoint" "finishline_eks_endpoint" {
  count = var.create_eks_endpoints ? 1 : 0

  vpc_id              = aws_vpc.finishline_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.eks"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.finishline_private_subnet[0].id]
  private_dns_enabled = var.private_dns_enabled

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-endpoint"
  })
}
#__________________________*** STS Endpoints ***__________________________
resource "aws_vpc_endpoint" "finishline_sts_endpoint" {
  count = var.create_sts_endpoint ? 1 : 0

  vpc_id              = aws_vpc.finishline_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.finishline_private_subnet[0].id]
  private_dns_enabled = var.private_dns_enabled

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-sts-endpoint"
  })
}
#_________________________*** EC2 Endpoints *** __________________________
resource "aws_vpc_endpoint" "finishline_ec2_endpoint" {
  count = var.create_ec2_endpoint ? 1 : 0

  vpc_id              = aws_vpc.finishline_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.finishline_private_subnet[0].id]
  private_dns_enabled = var.private_dns_enabled

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-ec2-endpoint"
  })
}
#__________________________*** S3 Endpoints *** __________________________
resource "aws_vpc_endpoint" "finishline_s3_endpoint" {
  count = var.create_s3_endpoint ? 1 : 0

  vpc_id            = aws_vpc.finishline_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.finishline_private_route_table[*].id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-s3-endpoint"
  })
}
