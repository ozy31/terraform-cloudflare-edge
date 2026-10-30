locals {
  tags = {
    Project     = "edge"
    Environment = "prod"
    ManagedBy   = "terraform"
    Repository  = "github.com/ozy31/terraform-cloudflare-edge"
  }
}

################################################################################
# WAF, geo-fence, rate limits
################################################################################

module "zone_security" {
  source = "../../modules/zone-security"

  account_id = var.account_id
  zone_id    = var.zone_id
  name       = "prod"

  # Licensed markets only; verified bots (search engines) are still allowed.
  allowed_countries = ["TR", "DE", "NL", "GB"]

  partner_ips = {
    "payment-provider-a" = "203.0.113.0/24"
    "odds-feed-b"        = "198.51.100.16/28"
  }

  office_ips = {
    "istanbul-office" = "192.0.2.10/32"
    "vpn-egress"      = "192.0.2.64/27"
  }

  api_hostnames = ["api.${var.domain}"]

  # Start in log mode, review Security Events for false positives, then block.
  owasp_action = "log"

  rate_limits = {
    login = {
      expression          = "http.request.uri.path eq \"/api/auth/login\" and http.request.method eq \"POST\""
      requests_per_period = 10
      mitigation_timeout  = 900
      action              = "managed_challenge"
    }
    api = {
      expression          = "http.host eq \"api.${var.domain}\""
      requests_per_period = 1200
    }
    llm = {
      expression          = "http.host eq \"llm.${var.domain}\""
      requests_per_period = 120
    }
  }
}

################################################################################
# Logs: Logpush -> S3 (tiered storage) -> OpenSearch
################################################################################

module "logpush" {
  source = "../../modules/logpush-s3"

  zone_id = var.zone_id
  name    = "prod"

  opensearch = var.opensearch_domain == null ? null : {
    domain_arn      = var.opensearch_domain.arn
    domain_endpoint = "https://${var.opensearch_domain.endpoint}"
  }

  tags = local.tags
}

################################################################################
# Internal tools and the self-hosted LLM, published without a public load balancer
################################################################################

module "tunnel" {
  source = "../../modules/tunnel"

  account_id       = var.account_id
  zone_id          = var.zone_id
  name             = "prod-euw1"
  access_team_name = var.access_team_name

  services = {
    grafana = {
      hostname              = "grafana.${var.domain}"
      service               = "http://kube-prometheus-stack-grafana.monitoring.svc:80"
      allowed_email_domains = [var.domain]
    }
    argocd = {
      hostname              = "argocd.${var.domain}"
      service               = "http://argocd-server.argocd.svc:80"
      allowed_email_domains = [var.domain]
      session_duration      = "4h"
    }
    # vLLM from terraform-aws-eks-ai-cluster; called by internal services with a service token.
    llm = {
      hostname              = "llm.${var.domain}"
      service               = "http://qwen3-8b.inference.svc:8000"
      allowed_email_domains = [var.domain]
      service_token         = true
    }
  }
}

################################################################################
# AI Gateway for third-party models (Anthropic, OpenAI)
################################################################################

module "ai_gateway" {
  source = "../../modules/ai-gateway"

  account_id = var.account_id
  gateway_id = "prod"

  rate_limit = {
    requests         = 300
    interval_seconds = 60
  }
}
