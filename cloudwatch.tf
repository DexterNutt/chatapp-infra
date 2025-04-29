resource "aws_cloudwatch_log_group" "chat_app_logs" {
  name = local.resource_names.logs

  tags = local.common_tags
}