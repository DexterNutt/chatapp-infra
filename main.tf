terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = local.region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "vpc_id" {
  value = aws_vpc.chat_app_vpc.id
}

output "db_endpoint" {
  value = aws_db_instance.chat_app_db.endpoint
}

output "ecr_repository_url" {
  value = aws_ecr_repository.chat_app_repo.repository_url
}

output "s3_bucket_name" {
  value = aws_s3_bucket.chat_app_bucket.bucket
}

output "s3_bucket_domain_name" {
  value = aws_s3_bucket.chat_app_bucket.bucket_domain_name
}

resource "tls_private_key" "ecs_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  filename        = "ecs-key.pem"
  content         = tls_private_key.ecs_key.private_key_openssh
  file_permission = "0400"
}

resource "aws_key_pair" "ecs_key_pair" {
  key_name   = "${local.name_prefix}-ecs-ssh-key"  
  public_key = tls_private_key.ecs_key.public_key_openssh
  tags       = local.common_tags
}

