locals {
  project_name = var.application_name
  environment  = var.environment
  region       = var.aws_region

  common_tags = {
    Name        = local.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
    Project     = "Intern"
  }
  # Networking
  vpc_cidr              = "15.0.0.0/20"
  public_subnet_cidr    = "15.0.1.0/25"
  private_subnet_1_cidr = "15.0.2.0/25"
  private_subnet_2_cidr = "15.0.3.0/25"
  # Compute
  instance_type    = "t3.micro"
  min_capacity     = 1
  max_capacity     = 1
  desired_capacity = 1
  # Database
  db_instance_class = "db.t3.micro"
  db_storage_size   = 20
  db_engine         = "postgres"
  db_engine_version = "16.4"
  db_name           = "chatdb"
  db_port           = 5432
  # Application
  app_port    = 3000
  name_prefix = "${local.project_name}-${local.environment}"
  resource_names = {
    vpc              = "${local.name_prefix}-vpc"
    igw              = "${local.name_prefix}-igw"
    nat              = "${local.name_prefix}-nat"
    public_subnet    = "${local.name_prefix}-public-subnet"
    private_subnet_1 = "${local.name_prefix}-private-subnet-1"
    private_subnet_2 = "${local.name_prefix}-private-subnet-2"
    public_rt        = "${local.name_prefix}-public-rt"
    private_rt       = "${local.name_prefix}-private-rt"
    app_sg           = "${local.name_prefix}-app-sg"
    db_sg            = "${local.name_prefix}-db-sg"
    ecs_cluster      = "${local.name_prefix}-cluster"
    ecs_capacity     = "${local.name_prefix}-capacity"
    ecs_asg          = "${local.name_prefix}-ecs-asg"
    ecs_lt           = "${local.name_prefix}-launch-template"
    ecs_task         = "${local.name_prefix}-task"
    ecs_service      = "${local.name_prefix}-service"
    ecs_container    = "${local.name_prefix}-container"
    ecs_instance     = "${local.name_prefix}-ecs-instance"
    ecr_repo         = "${local.name_prefix}-repo"
    task_role        = "${local.name_prefix}-task-execution-role"
    instance_role    = "${local.name_prefix}-instance-role"
    instance_profile = "${local.name_prefix}-ecs-instance-profile"
    s3_policy        = "${local.name_prefix}-s3-access-policy"
    logs             = "/ecs/${local.name_prefix}"
    db_subnet_group  = "${local.name_prefix}-db-subnet-group"
    db_instance      = "${local.name_prefix}-db"
    s3_bucket        = "${local.name_prefix}-${data.aws_caller_identity.current.account_id}"
  }
}

# Add the caller identity data source required for the s3_bucket name
data "aws_caller_identity" "current" {}

provider "aws" {
  region = local.region
  default_tags {
    tags = {
      Project = "Intern"
    }
  }
}
# ------------------------------
# VPC Configuration
# ------------------------------
resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.common_tags, {
    Name = local.resource_names.vpc
  })
}


resource "aws_subnet" "public" {
  count                   = 1
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(local.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = merge(local.common_tags, {
    Name = "${local.resource_names.public_subnet}-${count.index + 1}"
  })
}
# Private subnets - for RDS
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(local.common_tags, {
    Name = count.index == 0 ? local.resource_names.private_subnet_1 : local.resource_names.private_subnet_2
  })
}
data "aws_availability_zones" "available" {
  state = "available"
}
# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.common_tags, {
    Name = local.resource_names.igw
  })
}
# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = merge(local.common_tags, {
    Name = local.resource_names.public_rt
  })
}
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
# ------------------------------
# NAT Gateway Configuration
# ------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.resource_names.nat}-eip"
  })
}
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags = merge(local.common_tags, {
    Name = local.resource_names.nat
  })
  depends_on = [aws_internet_gateway.main]
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = merge(local.common_tags, {
    Name = local.resource_names.private_rt
  })
}
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
# ------------------------------
# S3 Bucket Configuration
# ------------------------------
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}
resource "aws_s3_bucket" "app_data" {
  bucket = local.resource_names.s3_bucket # Use the pre-defined bucket name with account ID
  tags = merge(local.common_tags, {
    Name = "${local.project_name} S3 Bucket"
  })
}
resource "aws_s3_bucket_ownership_controls" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
resource "aws_s3_bucket_acl" "app_data" {
  depends_on = [aws_s3_bucket_ownership_controls.app_data]
  bucket     = aws_s3_bucket.app_data.id
  acl        = "private"
}
resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket                  = aws_s3_bucket.app_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
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
# ------------------------------
# IAM Role for S3 Access
# ------------------------------
resource "aws_iam_policy" "s3_access" {
  name        = local.resource_names.s3_policy
  description = "Allow ECS tasks to access S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Effect = "Allow",
        Resource = [
          aws_s3_bucket.app_data.arn,
          "${aws_s3_bucket.app_data.arn}/*"
        ]
      }
    ]
  })
  tags = merge(local.common_tags, {
    Name = local.resource_names.s3_policy
  })
}
# ------------------------------
# ECS Cluster Configuration
# ------------------------------
resource "aws_ecs_cluster" "app_cluster" {
  name = local.resource_names.ecs_cluster

  tags = merge(local.common_tags, {
    Name = local.resource_names.ecs_cluster
  })
}
resource "aws_security_group" "ecs_sg" {
  name        = local.resource_names.app_sg
  description = "Allow HTTP and app traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = local.app_port
    to_port     = local.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr] # Using variable for SSH CIDR
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = local.resource_names.app_sg
  })
}

# Create SSH key pair from variable if provided
resource "aws_key_pair" "ssh_key" {
  count      = var.ssh_public_key != "" ? 1 : 0
  key_name   = var.ssh_key_name != "" ? var.ssh_key_name : "${local.name_prefix}-key"
  public_key = var.ssh_public_key

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-key"
  })
}

resource "aws_launch_template" "ecs_ec2" {
  name_prefix   = local.resource_names.ecs_lt
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = local.instance_type
  key_name      = var.ssh_public_key != "" ? (var.ssh_key_name != "" ? var.ssh_key_name : "${local.name_prefix}-key") : null
  
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ecs_sg.id]
    subnet_id                   = aws_subnet.public[0].id
  }
  
  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_ec2.name
  }
  
  user_data = base64encode(<<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.app_cluster.name} >> /etc/ecs/ecs.config
EOF
  )
  
  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = local.resource_names.ecs_instance
    })
  }
  tags = merge(local.common_tags, {
    Name = local.resource_names.ecs_lt
  })
}

resource "aws_autoscaling_group" "ecs_asg" {
  name                = local.resource_names.ecs_asg
  min_size            = local.min_capacity
  max_size            = local.max_capacity
  desired_capacity    = local.desired_capacity
  vpc_zone_identifier = [for subnet in aws_subnet.public : subnet.id]

  launch_template {
    id      = aws_launch_template.ecs_ec2.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  tag {
    key                 = "Name"
    value               = local.resource_names.ecs_instance
    propagate_at_launch = true
  }
}
# ------------------------------
# IAM Configuration
# ------------------------------
resource "aws_iam_instance_profile" "ecs_ec2" {
  name = local.resource_names.instance_profile
  role = aws_iam_role.ec2_role.name

  tags = merge(local.common_tags, {
    Name = local.resource_names.instance_profile
  })
}
resource "aws_iam_role" "ec2_role" {
  name = local.resource_names.instance_role

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = local.resource_names.instance_role
  })
}
resource "aws_iam_role_policy_attachment" "ec2_ecs_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}
resource "aws_iam_role" "ecs_task_execution_role" {
  name = local.resource_names.task_role

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = local.resource_names.task_role
  })
}
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy_attachment" "ecs_s3_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}
# Add policy to allow access to RDS
resource "aws_iam_policy" "rds_access" {
  name        = "${local.name_prefix}-rds-access-policy"
  description = "Allow ECS tasks to access RDS"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-access-policy"
  })
}
resource "aws_iam_role_policy_attachment" "ecs_rds_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.rds_access.arn
}
# ------------------------------
# AMI Data Source
# ------------------------------
data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
# ------------------------------
# ECS Task Definitions
# ------------------------------
resource "aws_ecs_task_definition" "my_app" {
  family                   = local.resource_names.ecs_task
  network_mode             = "host"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  cpu                      = 512
  memory                   = 1024

  container_definitions = jsonencode([{
    name      = local.resource_names.ecs_container
    image     = "590184111199.dkr.ecr.${local.region}.amazonaws.com/my-app:latest"
    cpu       = 512
    memory    = 1024
    essential = true
    portMappings = [{
      containerPort = local.app_port
      hostPort      = local.app_port
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = local.resource_names.logs
        awslogs-region        = local.region
        awslogs-stream-prefix = "ecs"
      }
    }
    environment = [
      {
        name  = "DB_HOST"
        value = aws_db_instance.postgres.address
      },
      {
        name  = "DB_PORT"
        value = tostring(local.db_port)
      },
      {
        name  = "DB_NAME"
        value = aws_db_instance.postgres.db_name
      },
      {
        name  = "DB_USER"
        value = aws_db_instance.postgres.username
      },
      {
        name  = "S3_BUCKET"
        value = aws_s3_bucket.app_data.bucket
      }
    ]
    secrets = [
      {
        name      = "DB_PASSWORD"
        valueFrom = "arn:aws:ssm:${local.region}:${data.aws_caller_identity.current.account_id}:parameter/myapp/db/password"
      }
    ]
  }])

  tags = merge(local.common_tags, {
    Name = local.resource_names.ecs_task
  })
}
resource "aws_ecs_task_definition" "nginx" {
  family                   = "${local.name_prefix}-nginx-task"
  network_mode             = "host"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  cpu                      = 256
  memory                   = 512

  container_definitions = jsonencode([{
    name      = "nginx"
    image     = "590184111199.dkr.ecr.${local.region}.amazonaws.com/my-nginx:latest"
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/nginx-${local.name_prefix}"
        awslogs-region        = local.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nginx-task"
  })
}
# ------------------------------
# ECS Services
# ------------------------------
resource "aws_ecs_service" "my_app" {
  name            = local.resource_names.ecs_service
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.my_app.arn
  desired_count   = local.desired_capacity
  launch_type     = "EC2"

  tags = merge(local.common_tags, {
    Name = local.resource_names.ecs_service
  })
}
resource "aws_ecs_service" "nginx" {
  name            = "${local.name_prefix}-nginx-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = local.desired_capacity
  launch_type     = "EC2"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nginx-service"
  })
}
# ------------------------------
# CloudWatch Log Groups
# ------------------------------
resource "aws_cloudwatch_log_group" "my_app" {
  name              = local.resource_names.logs
  retention_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix} App Logs"
  })
}
resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/ecs/nginx-${local.name_prefix}"
  retention_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix} Nginx Logs"
  })
}
# ------------------------------
# SSM Parameter for database password
# ------------------------------
resource "aws_ssm_parameter" "db_password" {
  name        = "/myapp/db/password"
  description = "PostgreSQL database password"
  type        = "SecureString"
  value       = var.db_password
  tags = merge(local.common_tags, {
    Name = "Database Password Parameter"
  })
}
# ------------------------------
# Outputs
# ------------------------------
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}
output "public_subnet_ids" {
  description = "The IDs of the public subnets"
  value       = aws_subnet.public[*].id
}
output "private_subnet_ids" {
  description = "The IDs of the private subnets"
  value       = aws_subnet.private[*].id
}
output "rds_endpoint" {
  description = "The connection endpoint for the PostgreSQL RDS instance"
  value       = aws_db_instance.postgres.endpoint
}
output "s3_bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.app_data.bucket
}
output "nat_gateway_public_ip" {
  description = "The public IP address of the NAT Gateway"
  value       = aws_nat_gateway.main.public_ip
}