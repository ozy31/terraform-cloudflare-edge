output "partner_list_name" {
  description = "Name of the partner IP list ($name in rule expressions)."
  value       = cloudflare_list.partners.name
}

output "office_list_name" {
  description = "Name of the office IP list ($name in rule expressions)."
  value       = cloudflare_list.office.name
}

output "ruleset_ids" {
  description = "IDs of the rulesets this module owns, by phase."
  value = {
    http_request_firewall_managed = cloudflare_ruleset.managed_waf.id
    http_request_firewall_custom  = cloudflare_ruleset.custom.id
    http_ratelimit                = try(cloudflare_ruleset.rate_limit[0].id, null)
  }
}
