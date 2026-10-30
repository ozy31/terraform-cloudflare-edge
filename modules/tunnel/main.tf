################################################################################
# Tunnel (remotely managed: ingress lives in Cloudflare, not in a config file)
################################################################################

resource "random_bytes" "tunnel_secret" {
  length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id    = var.account_id
  name          = var.name
  config_src    = "cloudflare"
  tunnel_secret = random_bytes.tunnel_secret.base64
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "this" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

################################################################################
# Access: every published hostname requires an identity or a service token
################################################################################

resource "cloudflare_zero_trust_access_service_token" "this" {
  for_each = { for k, s in var.services : k => s if s.service_token }

  account_id = var.account_id
  name       = "${var.name}-${each.key}"
  duration   = "8760h"
}

resource "cloudflare_zero_trust_access_policy" "humans" {
  for_each = { for k, s in var.services : k => s if length(s.allowed_email_domains) > 0 }

  account_id       = var.account_id
  name             = "${var.name}-${each.key}-humans"
  decision         = "allow"
  session_duration = each.value.session_duration

  include = [for d in each.value.allowed_email_domains : { email_domain = { domain = d } }]
}

resource "cloudflare_zero_trust_access_policy" "machines" {
  for_each = cloudflare_zero_trust_access_service_token.this

  account_id = var.account_id
  name       = "${var.name}-${each.key}-machines"
  decision   = "non_identity"

  include = [{ service_token = { token_id = each.value.id } }]
}

resource "cloudflare_zero_trust_access_application" "this" {
  for_each = var.services

  zone_id          = var.zone_id
  name             = "${var.name}-${each.key}"
  type             = "self_hosted"
  domain           = each.value.hostname
  session_duration = each.value.session_duration

  # Machine clients get a 401 instead of a login redirect.
  service_auth_401_redirect = true

  policies = concat(
    contains(keys(cloudflare_zero_trust_access_policy.humans), each.key) ? [{
      id         = cloudflare_zero_trust_access_policy.humans[each.key].id
      precedence = 1
    }] : [],
    contains(keys(cloudflare_zero_trust_access_policy.machines), each.key) ? [{
      id         = cloudflare_zero_trust_access_policy.machines[each.key].id
      precedence = 2
    }] : [],
  )
}

################################################################################
# Ingress rules + DNS
################################################################################

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id

  config = {
    ingress = concat(
      [
        for k, s in var.services : {
          hostname = s.hostname
          service  = s.service
          origin_request = {
            # Defence in depth: cloudflared itself rejects requests without a
            # valid Access JWT for this application, even if Access were misconfigured.
            access = {
              required  = true
              team_name = var.access_team_name
              aud_tag   = [cloudflare_zero_trust_access_application.this[k].aud]
            }
            connect_timeout = 10
          }
        }
      ],
      # Anything that does not match a hostname above.
      [{ service = "http_status:404" }],
    )
  }
}

resource "cloudflare_dns_record" "this" {
  for_each = var.services

  zone_id = var.zone_id
  name    = each.value.hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
  comment = "Cloudflare Tunnel ${var.name} -> ${each.value.service}"
}

################################################################################
# cloudflared connectors in the cluster
#
# Outbound-only: no public load balancer, no inbound security group rules.
################################################################################

resource "helm_release" "cloudflared" {
  name             = var.name
  namespace        = var.namespace
  create_namespace = true
  chart            = "${path.module}/charts/cloudflared"

  values = [yamlencode({
    replicas = var.replicas
    image    = { tag = var.image_tag }
    serviceMonitor = {
      enabled      = var.enable_service_monitor
      releaseLabel = var.prometheus_release_label
    }
  })]

  set_sensitive = [{
    name  = "tunnelToken"
    value = data.cloudflare_zero_trust_tunnel_cloudflared_token.this.token
  }]

  depends_on = [cloudflare_zero_trust_tunnel_cloudflared_config.this]
}
