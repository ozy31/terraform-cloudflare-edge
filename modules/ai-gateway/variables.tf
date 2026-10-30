variable "account_id" {
  description = "Cloudflare account ID."
  type        = string
}

variable "gateway_id" {
  description = "AI Gateway ID (appears in the endpoint URL)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,62}$", var.gateway_id))
    error_message = "gateway_id must be lowercase letters, digits and hyphens."
  }
}

variable "require_authentication" {
  description = "Require a cf-aig-authorization token on every request so the gateway URL alone is not enough to spend on your provider keys."
  type        = bool
  default     = true
}

variable "cache_ttl_seconds" {
  description = "Cache identical requests for this long. 0 disables caching. Useful for deterministic calls (classification, embeddings), not for chat."
  type        = number
  default     = 0
}

variable "rate_limit" {
  description = "Gateway-wide request limit: `requests` per `interval_seconds`, sliding or fixed window."
  type = object({
    requests         = number
    interval_seconds = number
    technique        = optional(string, "sliding")
  })
  default = {
    requests         = 600
    interval_seconds = 60
  }

  validation {
    condition     = contains(["sliding", "fixed"], var.rate_limit.technique)
    error_message = "rate_limit.technique must be sliding or fixed."
  }
}

variable "collect_logs" {
  description = "Store request/response logs in AI Gateway (prompt and completion analytics, cost per model)."
  type        = bool
  default     = true
}

variable "retries" {
  description = "Retry upstream provider errors from the gateway instead of every client."
  type = object({
    max_attempts = optional(number, 3)
    delay_ms     = optional(number, 500)
    backoff      = optional(string, "exponential")
  })
  default = {}
}

variable "providers_used" {
  description = "Upstream providers clients call through the gateway; one endpoint URL is output per provider."
  type        = list(string)
  default     = ["anthropic", "openai", "workers-ai"]
}
