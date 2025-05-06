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
# ECS Task Definitions
# ------------------------------
resource "aws_ecs_task_definition" "app" {
  family                   = local.resource_names.ecs_task
  network_mode             = "host"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  cpu                      = 512
  memory                   = 1024
  container_definitions = jsonencode([{
    name      = local.resource_names.ecs_container
    image     = aws_ecr_repository.app_repo.repository_url
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
    image     = aws_ecr_repository.nginx_repo.repository_url
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

resource "aws_ecs_task_definition" "migrations" {
  family                   = "${local.resource_names.ecs_task}-migrations"
  network_mode             = "host"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  cpu                      = 256
  memory                   = 512

  container_definitions = jsonencode([{
    name       = "${local.resource_names.ecs_container}-migrations"
    image      = "${aws_ecr_repository.app_repo.repository_url}:latest"
    cpu        = 256
    memory     = 512
    essential  = true
    entryPoint = ["bun"]
    command    = ["src/scripts/migrate.ts", "db-migrate"]

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
    Name = "${local.resource_names.ecs_task}-migrations"
  })
}

# ------------------------------
# ECS Services
# ------------------------------
resource "aws_ecs_service" "app" {
  name            = local.resource_names.ecs_service
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app.arn
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