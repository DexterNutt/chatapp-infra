# ------------------------------
# IAM Configuration
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


resource "aws_iam_role" "github_actions_role" {
  name = "${local.name_prefix}-github-actions-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.github_actions_user}"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-github-actions-role"
  })
}

resource "aws_iam_policy" "github_actions_policy" {
  name        = "${local.name_prefix}-github-actions-policy"
  description = "Policy for GitHub Actions to deploy to ECR and ECS"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:ListImages",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ],
        Resource = [
          aws_ecr_repository.app_repo.arn,
          aws_ecr_repository.nginx_repo.arn
        ]
      },
      {
        Effect   = "Allow",
        Action   = "ecr:GetAuthorizationToken",
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "ecs:RunTask"
        ],
        Resource = [
          aws_ecs_service.app.id,
          aws_ecs_service.nginx.id,
          aws_ecs_cluster.app_cluster.arn,
          "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:task-definition/${local.name_prefix}-task-migrations:*"
        ]
      },
      {
        Effect = "Allow",
        Action = "iam:PassRole",
        Resource = [
          aws_iam_role.ecs_task_execution_role.arn
        ]
      }
    ]
  })
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-github-actions-policy"
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_policy_attachment" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.github_actions_policy.arn
}

resource "aws_iam_user_policy" "assume_github_actions_role" {
  count = var.create_github_actions_user_policy ? 1 : 0
  name  = "${local.name_prefix}-assume-github-actions-role"
  user  = var.github_actions_user
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sts:AssumeRole",
        Resource = aws_iam_role.github_actions_role.arn
      }
    ]
  })
}

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
