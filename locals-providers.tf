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

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

provider "aws" {
  region = local.region
  default_tags {
    tags = {
      Project = "Intern"
    }
  }
}