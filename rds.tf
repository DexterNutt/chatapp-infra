resource "aws_db_subnet_group" "chat_db_subnet_group" {
  name       = "chat-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "chat-db-subnet-group"
    Project = "Intern"
  }
}

resource "aws_db_instance" "chat_app_db" {
  identifier             = "chat-app-db"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "15.3"
  username               = "chatadmin"
  password               = "chatadmin"
  db_name                = "chatdb"
  db_subnet_group_name   = aws_db_subnet_group.chat_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false 

  tags = {
    Project = "Intern"
  }
}