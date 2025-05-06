# ------------------------------
# S3 Bucket Configuration
# ------------------------------
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "app_data" {
  bucket = local.resource_names.s3_bucket
  tags = merge(local.common_tags, {
    Name = "${local.project_name} S3 Bucket"
  })
}

resource "aws_s3_bucket_ownership_controls" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "app_data" {
  depends_on = [aws_s3_bucket_ownership_controls.app_data]
  bucket     = aws_s3_bucket.app_data.id
  acl        = "private"
}

resource "aws_s3_bucket_versioning" "app_data" {
  bucket = aws_s3_bucket.app_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket                  = aws_s3_bucket.app_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}