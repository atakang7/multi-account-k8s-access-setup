resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = var.name
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name                                = "${var.name}-public-${count.index}"
    "kubernetes.io/cluster/${var.name}" = "shared"
    "kubernetes.io/role/elb"           = "1"
  }
}


resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = element(var.azs, count.index)

  tags = {
    Name                                = "${var.name}-private-${count.index}"
    "kubernetes.io/cluster/${var.name}" = "shared"
    "kubernetes.io/role/internal-elb"   = "1"
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# SSM VPC Endpoints for Session Manager
resource "aws_vpc_endpoint" "ssm" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids   = [for subnet in aws_subnet.private : subnet.id]

  private_dns_enabled = true
  security_group_ids  = [var.ssm_endpoint_sg]

  tags = {
    Name = "${var.name}-ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type = "Interface"
  subnet_ids   = [for subnet in aws_subnet.private : subnet.id]

  private_dns_enabled = true
  security_group_ids  = [var.ssm_endpoint_sg]

  tags = {
    Name = "${var.name}-ssmmessages-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type = "Interface"
  subnet_ids   = [for subnet in aws_subnet.private : subnet.id]

  private_dns_enabled = true
  security_group_ids  = [var.ssm_endpoint_sg]

  tags = {
    Name = "${var.name}-ec2messages-endpoint"
  }
}


resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.name}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}