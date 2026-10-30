locals {
  partner_list = "${var.name}_partners"
  office_list  = "${var.name}_office"

  countries = join(" ", [for c in var.allowed_countries : "\"${c}\""])
  admin     = join(" or ", [for p in var.admin_paths : "starts_with(http.request.uri.path, \"${p}\")"])
  api_hosts = join(" ", [for h in var.api_hostnames : "\"${h}\""])

  # Cloudflare-published managed rulesets (IDs are the same in every account).
  cloudflare_managed_ruleset_id = "efb7b8c949ac4650a09736fc376e9aee"
  owasp_core_ruleset_id         = "4814384a9e5d4991b9815dcfc25d2f1f"
  owasp_anomaly_rule_id         = "6179ae15870a4bb7b2d480d4843b323c"

  custom_rules = concat(
    [{
      ref         = "partner_bypass"
      description = "Partners and payment providers skip custom rules and rate limiting"
      expression  = "ip.src in $${local.partner_list}"
      action      = "skip"
      action_parameters = {
        ruleset = "current"
        phases  = ["http_ratelimit"]
      }
      logging = { enabled = true }
    }],
    length(var.allowed_countries) > 0 ? [{
      ref               = "geo_fence"
      description       = "Only serve licensed markets"
      expression        = "not ip.src.country in {${local.countries}} and not cf.client.bot"
      action            = "block"
      action_parameters = null
      logging           = null
    }] : [],
    length(var.admin_paths) > 0 ? [{
      ref               = "admin_office_only"
      description       = "Admin and internal paths only from office / VPN"
      expression        = "(${local.admin}) and not ip.src in $${local.office_list}"
      action            = "block"
      action_parameters = null
      logging           = null
    }] : [],
    length(var.api_hostnames) > 0 ? [{
      ref               = "api_empty_user_agent"
      description       = "API clients must identify themselves"
      expression        = "http.host in {${local.api_hosts}} and len(http.user_agent) eq 0"
      action            = "block"
      action_parameters = null
      logging           = null
    }] : [],
  )
}

################################################################################
# Zone settings
################################################################################

resource "cloudflare_zone_setting" "this" {
  for_each = var.zone_settings

  zone_id    = var.zone_id
  setting_id = each.key
  value      = each.value
}

################################################################################
# IP lists (account level, referenced from rule expressions as $name)
################################################################################

resource "cloudflare_list" "partners" {
  account_id  = var.account_id
  name        = local.partner_list
  kind        = "ip"
  description = "Partner and payment provider ranges for ${var.name}"

  items = [for comment, cidr in var.partner_ips : { ip = cidr, comment = comment }]
}

resource "cloudflare_list" "office" {
  account_id  = var.account_id
  name        = local.office_list
  kind        = "ip"
  description = "Office and VPN egress ranges for ${var.name}"

  items = [for comment, cidr in var.office_ips : { ip = cidr, comment = comment }]
}

################################################################################
# Managed WAF: Cloudflare Managed Ruleset + OWASP Core Ruleset
################################################################################

resource "cloudflare_ruleset" "managed_waf" {
  zone_id     = var.zone_id
  name        = "${var.name}-managed-waf"
  description = "Managed WAF rulesets"
  kind        = "zone"
  phase       = "http_request_firewall_managed"

  rules = [
    {
      ref         = "cloudflare_managed"
      description = "Cloudflare Managed Ruleset"
      expression  = "true"
      action      = "execute"
      action_parameters = {
        id = local.cloudflare_managed_ruleset_id
      }
    },
    {
      ref         = "owasp_core"
      description = "OWASP Core Ruleset (anomaly scoring)"
      expression  = "true"
      action      = "execute"
      action_parameters = {
        id = local.owasp_core_ruleset_id
        overrides = {
          rules = [{
            id              = local.owasp_anomaly_rule_id
            action          = var.owasp_action
            score_threshold = var.owasp_score_threshold
          }]
        }
      }
    },
  ]
}

################################################################################
# Custom rules: partner bypass, geo-fence, admin paths, API hygiene
################################################################################

resource "cloudflare_ruleset" "custom" {
  zone_id     = var.zone_id
  name        = "${var.name}-custom"
  description = "Custom firewall rules"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules = [
    for r in local.custom_rules : {
      ref               = r.ref
      description       = r.description
      expression        = r.expression
      action            = r.action
      action_parameters = r.action_parameters
      logging           = r.logging
    }
  ]

  depends_on = [cloudflare_list.partners, cloudflare_list.office]
}

################################################################################
# Rate limiting
################################################################################

resource "cloudflare_ruleset" "rate_limit" {
  count = length(var.rate_limits) > 0 ? 1 : 0

  zone_id     = var.zone_id
  name        = "${var.name}-rate-limit"
  description = "Rate limiting rules"
  kind        = "zone"
  phase       = "http_ratelimit"

  rules = [
    for name, r in var.rate_limits : {
      ref         = name
      description = "Rate limit: ${name}"
      expression  = r.expression
      action      = r.action
      ratelimit = {
        characteristics     = ["cf.colo.id", "ip.src"]
        period              = r.period
        requests_per_period = r.requests_per_period
        mitigation_timeout  = r.mitigation_timeout
      }
    }
  ]
}
