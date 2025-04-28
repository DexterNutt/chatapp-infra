#* VPC
resource "aws_vpc" "chat_app_vpc" {
  cidr_block = "15.0.0.0/20"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-vpc"
  })
}

#* Internet Gateway
resource "aws_internet_gateway" "chat_app_igw" {
  vpc_id = aws_vpc.chat_app_vpc.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-igw"
  })
}

#* Subnets
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.chat_app_vpc.id
  cidr_block        = "15.0.1.0/25"
  availability_zone = "${local.region}a"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-public-subnet"
  })
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.chat_app_vpc.id
  cidr_block        = "15.0.2.0/25"
  availability_zone = "${local.region}a"

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-private-subnet-1"
  })
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.chat_app_vpc.id
  cidr_block        = "15.0.3.0/25"
  availability_zone = "${local.region}a"

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-private-subnet-2"
  })
}

#* Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.chat_app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.chat_app_igw.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.chat_app_vpc.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-private-rt"
  })
}

resource "aws_route_table_association" "private_subnet_1_association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_subnet_2_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = local.common_tags
}

resource "aws_nat_gateway" "chat_app_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-nat"
  })

  depends_on = [aws_internet_gateway.chat_app_igw]
}

resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.chat_app_nat.id
}