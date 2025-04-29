resource "aws_s3_bucket" "chat_app_bucket" {
  bucket = "${local.project_name}-${data.aws_caller_identity.current.account_id}"

  tags = local.common_tags
}

resource "aws_s3_bucket_ownership_controls" "chat_app_bucket_ownership" {
  bucket = aws_s3_bucket.chat_app_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "chat_app_bucket_access" {
  bucket = aws_s3_bucket.chat_app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "chat_app_bucket_versioning" {
  bucket = aws_s3_bucket.chat_app_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "chat_app_bucket_encryption" {
  bucket = aws_s3_bucket.chat_app_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
