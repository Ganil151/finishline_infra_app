resource "aws_vpc" "finishline_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = {
    Name     = "${var.project_name}-${var.environment}-vpc"
    ManageBy = "${var.manage_by}"
  }
}

resource "aws_internet_gateway" "finishline_igw" {
  vpc_id = aws_vpc.finishline_vpc.id

  tags = {
    Name     = "${var.project_name}-${var.environment}-igw"
    ManageBy = "${var.manage_by}"
  }
}

resource "aws_subnet" "finishline_public_subnet" {
  count                   = length(var.public_subnets_cidrs)
  vpc_id                  = aws_vpc.finishline_vpc.id
  cidr_block              = var.public_subnets_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                                           = "${var.project_name}-${var.environment}-public-${count.index + 1}"
    ManageBy                                                       = "${var.manage_by}"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "owned"

  }
}

resource "aws_subnet" "finishline_private_subnet" {
  count             = length(var.private_subnets_cidrs)
  vpc_id            = aws_vpc.finishline_vpc.id
  cidr_block        = var.private_subnets_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                                                           = "${var.project_name}-${var.environment}-private-${count.index + 1}"
    ManageBy                                                       = "${var.manage_by}"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "owned"
  }
}

resource "aws_eip" "finishline_eip" {
  domain = "vpc"

  tags = {
    Name     = "${var.project_name}-${var.environment}-eip"
    ManageBy = "${var.manage_by}"
  }

}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.finishline_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.finishline_igw.id
  }
  tags = {
    Name     = "${var.project_name}-public-rt"
    ManageBy = "${var.manage_by}"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets_cidrs)
  subnet_id      = aws_subnet.finishline_public_subnet[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.finishline_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.finishline_igw.id
  }
  tags = {
    Name     = "${var.project_name}-private-rt"
    ManageBy = "${var.manage_by}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets_cidrs)
  subnet_id      = aws_subnet.finishline_private_subnet[count.index].id
  route_table_id = aws_route_table.private.id
}
