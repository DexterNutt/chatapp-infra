resource "aws_ecr_repository" "chat_app_repo" {
  name                 = "${local.project_name}-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}
