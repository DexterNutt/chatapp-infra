resource "aws_security_group" "app_sg" {
  name        = local.resource_names.app_sg
  description = "Security group for chat application ECS tasks"
  vpc_id      = aws_vpc.chat_app_vpc.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere"
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from anywhere"
  }
  
  ingress {
    from_port   = local.app_port
    to_port     = local.app_port
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.chat_app_vpc.cidr_block]
    description = "Allow app port only from within VPC"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = merge(local.common_tags, {
    Name = local.resource_names.app_sg
  })
}

resource "aws_security_group" "db_sg" {
  name        = local.resource_names.db_sg
  description = "Security group for chat application database"
  vpc_id      = aws_vpc.chat_app_vpc.id
  
  ingress {
    description     = "Allow PostgreSQL from app security group"
    from_port       = local.db_port
    to_port         = local.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = merge(local.common_tags, {
    Name = local.resource_names.db_sg
  })
}