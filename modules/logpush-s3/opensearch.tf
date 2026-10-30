################################################################################
# Optional: S3 -> SQS -> OpenSearch Ingestion
################################################################################

locals {
  osis_enabled = var.opensearch != null
}

resource "aws_sqs_queue" "osis" {
  count = local.osis_enabled ? 1 : 0

  name                       = "${var.name}-cloudflare-logs"
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600

  tags = var.tags
}

data "aws_iam_policy_document" "sqs" {
  count = local.osis_enabled ? 1 : 0

  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.osis[0].arn]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.logs.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "osis" {
  count = local.osis_enabled ? 1 : 0

  queue_url = aws_sqs_queue.osis[0].id
  policy    = data.aws_iam_policy_document.sqs[0].json
}

resource "aws_s3_bucket_notification" "osis" {
  count = local.osis_enabled ? 1 : 0

  bucket = aws_s3_bucket.logs.id

  queue {
    queue_arn     = aws_sqs_queue.osis[0].arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "cloudflare/"
    filter_suffix = ".log.gz"
  }

  depends_on = [aws_sqs_queue_policy.osis]
}

data "aws_iam_policy_document" "osis_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["osis-pipelines.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

data "aws_iam_policy_document" "osis" {
  count = local.osis_enabled ? 1 : 0

  statement {
    sid       = "ReadLogs"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.logs.arn}/cloudflare/*"]
  }

  statement {
    sid       = "ConsumeNotifications"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility"]
    resources = [aws_sqs_queue.osis[0].arn]
  }

  statement {
    sid       = "DescribeDomain"
    actions   = ["es:DescribeDomain"]
    resources = [var.opensearch.domain_arn]
  }

  statement {
    sid       = "WriteIndices"
    actions   = ["es:ESHttpGet", "es:ESHttpHead", "es:ESHttpPost", "es:ESHttpPut"]
    resources = ["${var.opensearch.domain_arn}/*"]
  }
}

resource "aws_iam_role" "osis" {
  count = local.osis_enabled ? 1 : 0

  name               = "${var.name}-cloudflare-logs-osis"
  assume_role_policy = data.aws_iam_policy_document.osis_trust.json

  tags = var.tags
}

resource "aws_iam_role_policy" "osis" {
  count = local.osis_enabled ? 1 : 0

  name   = "cloudflare-logs"
  role   = aws_iam_role.osis[0].id
  policy = data.aws_iam_policy_document.osis[0].json
}

resource "aws_osis_pipeline" "this" {
  count = local.osis_enabled ? 1 : 0

  pipeline_name = substr(replace("${var.name}-cf-logs", "_", "-"), 0, 28)
  min_units     = var.opensearch.min_units
  max_units     = var.opensearch.max_units

  pipeline_configuration_body = templatefile("${path.module}/templates/pipeline.yaml.tftpl", {
    queue_url = aws_sqs_queue.osis[0].url
    region    = local.region
    role_arn  = aws_iam_role.osis[0].arn
    endpoint  = var.opensearch.domain_endpoint
    datasets  = keys(var.datasets)
  })

  tags = var.tags

  depends_on = [aws_iam_role_policy.osis]
}
