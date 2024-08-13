resource "aws_s3_bucket" "default" {
  bucket        = local.common_tags.Name
  force_destroy = true

  tags = merge(local.tags, { Name = local.common_tags.Name })
}

resource "aws_s3_bucket_acl" "default" {
  bucket     = aws_s3_bucket.default.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.default]
}

resource "aws_s3_bucket_ownership_controls" "default" {
  bucket = aws_s3_bucket.default.id
  rule {
    object_ownership = var.object_ownership
  }
}

resource "aws_s3_bucket_public_access_block" "default" {
  bucket = aws_s3_bucket.default.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket_lifecycle_configuration" "default" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.default.id
  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id = rule.value.name
      expiration {
        days = rule.value.expiration.days
      }
      status = "Enabled"
    }
  }
}
