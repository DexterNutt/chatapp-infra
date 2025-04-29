resource "aws_ecs_cluster" "chat_app_cluster" {
  name = local.resource_names.ecs_cluster

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "chat_app_cluster_capacity" {
  cluster_name       = aws_ecs_cluster.chat_app_cluster.name
  capacity_providers = [aws_ecs_capacity_provider.chat_app_capacity.name]
}

resource "aws_ecs_capacity_provider" "chat_app_capacity" {
  name = local.resource_names.ecs_capacity

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.chat_app_asg.arn
    managed_scaling {
      status = "ENABLED"
    }
  }

  tags = local.common_tags
}

resource "aws_autoscaling_group" "chat_app_asg" {
  name                = local.resource_names.ecs_asg
  min_size            = local.min_capacity
  max_size            = local.max_capacity
  desired_capacity    = local.desired_capacity
  vpc_zone_identifier = [aws_subnet.private_subnet_1.id]

  launch_template {
    id      = aws_launch_template.chat_app_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = local.resource_names.ecs_instance
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
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
}

resource "aws_launch_template" "chat_app_launch_template" {
  name                   = local.resource_names.ecs_lt
  image_id               = data.aws_ami.ecs_ami.id
  instance_type          = local.instance_type
  update_default_version = true
  key_name               = aws_key_pair.ecs_key_pair.key_name
  vpc_security_group_ids = concat(
    [aws_security_group.app_sg.id],
    [aws_security_group.ecs_ssh_sg.id]
  )

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = local.resource_names.ecs_instance
    })
  }

  metadata_options {
    http_tokens = "required"
  }

  user_data = base64encode(<<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.chat_app_cluster.name} >> /etc/ecs/ecs.config
echo ECS_IMAGE_PULL_BEHAVIOR=always >> /etc/ecs/ecs.config
EOF
  )
}

resource "aws_ecs_task_definition" "chat_app_task" {
  family                   = local.resource_names.ecs_task
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = local.resource_names.ecs_container
    image     = "${aws_ecr_repository.chat_app_repo.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = local.app_port
      hostPort      = local.app_port
    }]
    environment = [
      {
        name  = "DB_HOST"
        value = aws_db_instance.chat_app_db.address
      },
      {
        name  = "DB_USER"
        value = aws_db_instance.chat_app_db.username
      },
      {
        name  = "DB_PASSWORD"
        value = aws_db_instance.chat_app_db.password
      },
      {
        name  = "DB_NAME"
        value = aws_db_instance.chat_app_db.db_name
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.chat_app_logs.name
        "awslogs-region"        = local.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = local.common_tags
}

resource "aws_ecs_service" "chat_app_service" {
  name            = local.resource_names.ecs_service
  cluster         = aws_ecs_cluster.chat_app_cluster.id
  task_definition = aws_ecs_task_definition.chat_app_task.arn
  desired_count   = local.desired_capacity

  ordered_placement_strategy {
    type  = "binpack"
    field = "cpu"
  }

  tags = local.common_tags
}

data "aws_ami" "ecs_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}