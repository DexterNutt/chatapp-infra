# ------------------------------
# CloudWatch Log Groups
# ------------------------------
resource "aws_cloudwatch_log_group" "app" {
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