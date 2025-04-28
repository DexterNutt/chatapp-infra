resource "aws_cloudwatch_log_group" "chat_app_logs" {
  name = "/ecs/${local.project_name}"

  tags = local.common_tags
}