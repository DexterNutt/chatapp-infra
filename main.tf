terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

locals {
  project_name = "chat-app"
  environment  = "intern"
  region       = "eu-north-1"
  
   common_tags = {
    Project     = "Intern"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
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