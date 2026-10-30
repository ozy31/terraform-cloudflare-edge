################################################################################
# AI Gateway in front of third-party LLM APIs
#
# Applications keep their own provider keys but send traffic to the gateway
# URL instead of the provider. That gives one place for rate limits, retries,
# caching, usage/cost analytics and logs across every model the company uses.
################################################################################

resource "cloudflare_ai_gateway" "this" {
  account_id = var.account_id
  id         = var.gateway_id

  authentication = var.require_authentication

  cache_ttl                  = var.cache_ttl_seconds
  cache_invalidate_on_update = true

  rate_limiting_limit     = var.rate_limit.requests
  rate_limiting_interval  = var.rate_limit.interval_seconds
  rate_limiting_technique = var.rate_limit.technique

  retry_max_attempts = var.retries.max_attempts
  retry_delay        = var.retries.delay_ms
  retry_backoff      = var.retries.backoff

  collect_logs = var.collect_logs
}
