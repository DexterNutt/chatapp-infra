resource "aws_vpc" "chat_app_vpc" {
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = local.resource_names.vpc
  })
}

resource "aws_internet_gateway" "chat_app_igw" {
  vpc_id = aws_vpc.chat_app_vpc.id

  tags = merge(local.common_tags, {
    Name = local.resource_names.igw
  })
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.chat_app_vpc.id
  cidr_block              = local.public_subnet_cidr
  availability_zone       = "${local.region}a"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = local.resource_names.public_subnet
  })
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.chat_app_vpc.id
  cidr_block        = local.private_subnet_1_cidr
  availability_zone = "${local.region}a"

  tags = merge(local.common_tags, {
    Name = local.resource_names.private_subnet_1
  })
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.chat_app_vpc.id
  cidr_block        = local.private_subnet_2_cidr
  availability_zone = "${local.region}a"

  tags = merge(local.common_tags, {
    Name = local.resource_names.private_subnet_2
  })
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.chat_app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.chat_app_igw.id
  }

  tags = merge(local.common_tags, {
    Name = local.resource_names.public_rt
  })
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.chat_app_vpc.id

  tags = merge(local.common_tags, {
    Name = local.resource_names.private_rt
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
    Name = local.resource_names.nat
  })

  depends_on = [aws_internet_gateway.chat_app_igw]
}

resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.chat_app_nat.id
}