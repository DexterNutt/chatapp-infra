# ------------------------------
# RDS PostgreSQL Configuration
# ------------------------------
resource "aws_db_subnet_group" "postgres" {
  name       = local.resource_names.db_subnet_group
  subnet_ids = aws_subnet.private[*].id
  tags = merge(local.common_tags, {
    Name = local.resource_names.db_subnet_group
  })
}

resource "aws_security_group" "rds_sg" {
  name        = local.resource_names.db_sg
  description = "Allow PostgreSQL traffic from ECS instances"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port       = local.db_port
    to_port         = local.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, {
    Name = local.resource_names.db_sg
  })
}

resource "aws_db_parameter_group" "postgres" {
  name   = "${local.name_prefix}-pg-params"
  family = "postgres16"
  parameter {
    name  = "log_connections"
    value = "1"
  }
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-pg-params"
  })
}

resource "aws_db_instance" "postgres" {
  identifier             = local.resource_names.db_instance
  allocated_storage      = local.db_storage_size
  db_name                = local.db_name
  engine                 = local.db_engine
  engine_version         = local.db_engine_version
  instance_class         = local.db_instance_class
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  parameter_group_name   = aws_db_parameter_group.postgres.name
  publicly_accessible    = false
  skip_final_snapshot    = true
  multi_az               = false
  storage_encrypted      = true
  tags = merge(local.common_tags, {
    Name = local.resource_names.db_instance
  })
}

# # ------------------------------
# # SSM Parameter for database password
# # ------------------------------
# resource "aws_ssm_parameter" "db_password" {
#   name        = "/myapp/db/password"
#   description = "PostgreSQL database password"
#   type        = "SecureString"
#   value       = var.db_password
#   tags = merge(local.common_tags, {
#     Name = "Database Password Parameter"
#   })
# }