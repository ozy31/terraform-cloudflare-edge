output "gateway_id" {
  description = "AI Gateway ID."
  value       = cloudflare_ai_gateway.this.id
}

output "base_url" {
  description = "Gateway base URL; append the provider segment."
  value       = "https://gateway.ai.cloudflare.com/v1/${var.account_id}/${cloudflare_ai_gateway.this.id}"
}

output "provider_endpoints" {
  description = "Drop-in base URLs per provider (for example ANTHROPIC_BASE_URL, OPENAI_BASE_URL)."
  value = {
    for p in var.providers_used : p => "https://gateway.ai.cloudflare.com/v1/${var.account_id}/${cloudflare_ai_gateway.this.id}/${p}"
  }
}
