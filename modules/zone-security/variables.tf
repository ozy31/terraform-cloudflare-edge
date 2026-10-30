variable "account_id" {
  description = "Cloudflare account ID. IP lists are account-level objects."
  type        = string
}

variable "zone_id" {
  description = "Cloudflare zone ID. This module owns the zone's managed WAF, custom rule and rate limiting phase entrypoints."
  type        = string
}

variable "name" {
  description = "Short name used in list and ruleset names (lowercase letters, digits and underscores)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9_]{1,40}$", var.name))
    error_message = "name may only contain lowercase letters, digits and underscores (max 40)."
  }
}

variable "zone_settings" {
  description = "Zone settings enforced by Terraform (setting_id => value). Defaults: Full (strict) TLS to origin, TLS 1.2+, HTTPS only."
  type        = map(string)
  default = {
    ssl                      = "strict"
    min_tls_version          = "1.2"
    tls_1_3                  = "on"
    always_use_https         = "on"
    automatic_https_rewrites = "on"
  }
}

variable "allowed_countries" {
  description = "ISO 3166-1 alpha-2 codes allowed to reach the zone (market launch / licensing geo-fence). Empty disables the geo rule."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.allowed_countries : can(regex("^[A-Z]{2}$", c))])
    error_message = "allowed_countries must be upper-case two-letter country codes."
  }
}

variable "partner_ips" {
  description = "Partner / payment provider source ranges (CIDR) that bypass geo, custom rules and rate limits. Managed WAF still inspects them."
  type        = map(string)
  default     = {}
}

variable "office_ips" {
  description = "Office / VPN egress ranges (CIDR) allowed to reach admin paths."
  type        = map(string)
  default     = {}
}

variable "admin_paths" {
  description = "Path prefixes only reachable from office_ips."
  type        = list(string)
  default     = ["/admin", "/internal", "/actuator"]
}

variable "api_hostnames" {
  description = "Hostnames serving machine-to-machine APIs. Requests without a User-Agent to these hosts are blocked."
  type        = list(string)
  default     = []
}

variable "owasp_score_threshold" {
  description = "OWASP Core Ruleset anomaly score threshold: 60 (low sensitivity), 40 (medium), 25 (high)."
  type        = number
  default     = 40

  validation {
    condition     = contains([25, 40, 60], var.owasp_score_threshold)
    error_message = "owasp_score_threshold must be 25, 40 or 60."
  }
}

variable "owasp_action" {
  description = "Action when the OWASP anomaly threshold is exceeded. Start with log, review false positives, then switch to block."
  type        = string
  default     = "log"

  validation {
    condition     = contains(["log", "block", "managed_challenge"], var.owasp_action)
    error_message = "owasp_action must be log, block or managed_challenge."
  }
}

variable "rate_limits" {
  description = <<-EOT
    Rate limiting rules keyed by name.

    expression          Cloudflare rules language filter for the requests that are counted.
    requests_per_period Requests allowed per period per client (counted per colo + IP).
    period              Window in seconds. Non-Enterprise plans support 10 (Pro/Business also 60).
    mitigation_timeout  Seconds the client stays blocked once over the limit.
    action              block or managed_challenge.
  EOT
  type = map(object({
    expression          = string
    requests_per_period = number
    period              = optional(number, 60)
    mitigation_timeout  = optional(number, 600)
    action              = optional(string, "block")
  }))
  default = {}

  validation {
    condition     = alltrue([for r in values(var.rate_limits) : contains(["block", "managed_challenge"], r.action)])
    error_message = "rate_limits[*].action must be block or managed_challenge."
  }
}
