variable "zone_id" {
  description = "Cloudflare zone whose logs are pushed. Zone-scoped Logpush datasets require an Enterprise plan."
  type        = string
}

variable "name" {
  description = "Name prefix for AWS resources and Logpush jobs."
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket for Cloudflare logs. Defaults to <name>-cloudflare-logs-<account_id>."
  type        = string
  default     = null
}

variable "datasets" {
  description = "Logpush datasets and the fields to export for each. Keep the field list tight: every field costs storage and indexing."
  type = map(object({
    fields = list(string)
    filter = optional(string)
  }))
  default = {
    http_requests = {
      fields = [
        "EdgeStartTimestamp", "RayID", "ClientIP", "ClientCountry", "ClientASN",
        "ClientRequestHost", "ClientRequestMethod", "ClientRequestURI", "ClientRequestUserAgent",
        "EdgeResponseStatus", "OriginResponseStatus", "OriginResponseDurationMs",
        "CacheCacheStatus", "SecurityAction", "WAFAttackScore",
      ]
    }
    firewall_events = {
      fields = [
        "Datetime", "RayID", "Action", "Source", "RuleID", "Description",
        "ClientIP", "ClientCountry", "ClientASN", "ClientRequestHost",
        "ClientRequestMethod", "ClientRequestPath", "ClientRequestQuery", "ClientRequestUserAgent",
      ]
    }
  }
}

variable "lifecycle_days" {
  description = "Storage class tiering: move to STANDARD_IA, then GLACIER_IR, then expire."
  type = object({
    standard_ia = optional(number, 30)
    glacier_ir  = optional(number, 90)
    expire      = optional(number, 365)
  })
  default = {}

  validation {
    condition = (
      var.lifecycle_days.standard_ia >= 30 &&
      var.lifecycle_days.glacier_ir > var.lifecycle_days.standard_ia &&
      var.lifecycle_days.expire > var.lifecycle_days.glacier_ir
    )
    error_message = "Need 30 <= standard_ia < glacier_ir < expire (S3 requires 30 days in STANDARD before IA)."
  }
}

variable "cloudflare_logpush_principal" {
  description = "AWS principal Cloudflare Logpush writes as (published by Cloudflare)."
  type        = string
  default     = "arn:aws:iam::391854517948:user/cloudflare-logpush"
}

variable "opensearch" {
  description = <<-EOT
    Optional OpenSearch Ingestion (OSIS) pipeline that indexes new log files.
    S3 ObjectCreated -> SQS -> OSIS (gunzip, parse NDJSON) -> OpenSearch index per dataset per day.
    The pipeline role must also be mapped to a backend role with write access in OpenSearch fine-grained access control.
  EOT
  type = object({
    domain_arn      = string
    domain_endpoint = string
    min_units       = optional(number, 1)
    max_units       = optional(number, 4)
  })
  default = null
}

variable "tags" {
  description = "Tags applied to AWS resources."
  type        = map(string)
  default     = {}
}
