data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  bucket_name = coalesce(var.bucket_name, "${var.name}-cloudflare-logs-${data.aws_caller_identity.current.account_id}")
  region      = data.aws_region.current.region

  destinations = {
    for ds, _ in var.datasets : ds => "s3://${local.bucket_name}/cloudflare/${ds}/{DATE}?region=${local.region}"
  }
}

################################################################################
# Log bucket
################################################################################

resource "aws_s3_bucket" "logs" {
  bucket = local.bucket_name

  tags = var.tags
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SSE-S3: Logpush writes with a plain PutObject from Cloudflare's own AWS
# principal, which cannot be granted use of a customer-managed key cleanly.
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Logs are hot for a few weeks (investigations), then kept cheaply for audit.
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "tier-and-expire"
    status = "Enabled"

    filter {
      prefix = "cloudflare/"
    }

    transition {
      days          = var.lifecycle_days.standard_ia
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.lifecycle_days.glacier_ir
      storage_class = "GLACIER_IR"
    }

    expiration {
      days = var.lifecycle_days.expire
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid       = "CloudflareLogpushWrite"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.logs.arn}/cloudflare/*"]

    principals {
      type        = "AWS"
      identifiers = [var.cloudflare_logpush_principal]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.bucket.json

  depends_on = [aws_s3_bucket_public_access_block.logs]
}

################################################################################
# Logpush jobs
#
# Cloudflare proves bucket ownership by writing a challenge file into the
# destination; Terraform reads it back and hands the token to the job.
################################################################################

resource "cloudflare_logpush_ownership_challenge" "this" {
  for_each = local.destinations

  zone_id          = var.zone_id
  destination_conf = each.value

  depends_on = [aws_s3_bucket_policy.logs]
}

data "aws_s3_object" "challenge" {
  for_each = local.destinations

  bucket = aws_s3_bucket.logs.id
  key    = trimprefix(cloudflare_logpush_ownership_challenge.this[each.key].filename, "/")
}

resource "cloudflare_logpush_job" "this" {
  for_each = var.datasets

  zone_id             = var.zone_id
  name                = replace("${var.name}-${each.key}", "_", "-")
  dataset             = each.key
  destination_conf    = local.destinations[each.key]
  ownership_challenge = trimspace(data.aws_s3_object.challenge[each.key].body)
  filter              = each.value.filter
  enabled             = true

  output_options = {
    output_type      = "ndjson"
    field_names      = each.value.fields
    timestamp_format = "rfc3339"
  }
}
