variable "account_id" {
  description = "Cloudflare account ID."
  type        = string
}

variable "zone_id" {
  description = "Zone the public hostnames live in."
  type        = string
}

variable "name" {
  description = "Tunnel name; also used for the Helm release and Access objects."
  type        = string
}

variable "access_team_name" {
  description = "Zero Trust team name (<team>.cloudflareaccess.com). cloudflared validates the Access JWT for protected services against it."
  type        = string
}

variable "services" {
  description = <<-EOT
    In-cluster services published through the tunnel, keyed by short name.

    hostname               Public hostname (must be in zone_id).
    service                Origin URL as seen from cloudflared, e.g. http://grafana.monitoring.svc:80.
    allowed_email_domains  Humans from these IdP email domains may sign in. Empty = no human access.
    service_token          Create an Access service token for machine clients (CI, other services, LLM consumers).
    session_duration       Access session lifetime.

    Every service is behind Cloudflare Access; there is deliberately no way to publish one unauthenticated.
  EOT
  type = map(object({
    hostname              = string
    service               = string
    allowed_email_domains = optional(list(string), [])
    service_token         = optional(bool, false)
    session_duration      = optional(string, "8h")
  }))

  validation {
    condition = alltrue([
      for s in values(var.services) : length(s.allowed_email_domains) > 0 || s.service_token
    ])
    error_message = "Each service needs allowed_email_domains, service_token, or both; otherwise nobody can reach it."
  }
}

variable "namespace" {
  description = "Kubernetes namespace for cloudflared."
  type        = string
  default     = "cloudflared"
}

variable "replicas" {
  description = "cloudflared replicas. Each keeps four connections to two Cloudflare data centres; two replicas across zones survive a node or AZ loss."
  type        = number
  default     = 2
}

variable "image_tag" {
  description = "cloudflare/cloudflared image tag."
  type        = string
  default     = "2026.10.6"
}

variable "enable_service_monitor" {
  description = "Create a ServiceMonitor for cloudflared metrics (requires Prometheus Operator CRDs)."
  type        = bool
  default     = true
}

variable "prometheus_release_label" {
  description = "Value of the `release` label the Prometheus Operator selects ServiceMonitors by."
  type        = string
  default     = "kube-prometheus-stack"
}
