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