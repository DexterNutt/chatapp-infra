variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-north-1"
}

variable "github_actions_user" {
  description = "Name of the IAM user that will assume the GitHub Actions role"
  type        = string
  default     = "demjan"
}

variable "create_github_actions_user_policy" {
  description = "Whether to create a policy for the IAM user to assume the GitHub Actions role"
  type        = bool
  default     = true
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

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH into ECS instances"
  type        = string
  default     = "0.0.0.0/0" #Home IP can be used here to restrict access from only one IP address
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair to use for ECS instances"
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "Public SSH key for accessing ECS instances"
  type        = string
  default     = ""
  sensitive   = true
}