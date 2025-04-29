resource "aws_db_subnet_group" "chat_db_subnet_group" {
  name       = local.resource_names.db_subnet_group
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = merge(local.common_tags, {
    Name = local.resource_names.db_subnet_group
  })
}

resource "aws_db_instance" "chat_app_db" {
  identifier        = local.resource_names.db_instance
  instance_class    = local.db_instance_class
  allocated_storage = local.db_storage_size

  engine         = local.db_engine
  engine_version = local.db_engine_version
  username       = var.db_username
  password       = var.db_password
  db_name        = local.db_name

  storage_encrypted            = true
  backup_retention_period      = 7
  performance_insights_enabled = true
  ca_cert_identifier           = "rds-ca-rsa2048-g1"

  db_subnet_group_name   = aws_db_subnet_group.chat_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false

  tags = local.common_tags
}