variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-north-1"
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "application_name" {
  description = "Name of the application"
  type        = string
  default     = "chat-app"
}

variable "db_username" {
  description = "Database administrator username"
  type        = string
  default     = "chatadmin"
}

variable "db_password" {
  description = "RDS root password"
  type        = string
  sensitive   = true
}