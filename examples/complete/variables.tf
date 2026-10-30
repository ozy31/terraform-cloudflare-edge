variable "cloudflare_api_token" {
  description = "Cloudflare API token."
  type        = string
  sensitive   = true
}

variable "account_id" {
  description = "Cloudflare account ID."
  type        = string
}

variable "zone_id" {
  description = "Cloudflare zone ID for example.com."
  type        = string
}

variable "domain" {
  description = "Zone apex."
  type        = string
  default     = "example.com"
}

variable "access_team_name" {
  description = "Cloudflare Zero Trust team name."
  type        = string
  default     = "example"
}

variable "region" {
  description = "AWS region for the log bucket and the EKS cluster."
  type        = string
  default     = "eu-west-1"
}

variable "cluster_name" {
  description = "EKS cluster that runs cloudflared."
  type        = string
  default     = "prod-euw1"
}

variable "opensearch_domain" {
  description = "Existing OpenSearch domain for log indexing (null to only archive in S3)."
  type = object({
    arn      = string
    endpoint = string
  })
  default = null
}
