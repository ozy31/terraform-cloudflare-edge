output "published_hostnames" {
  description = "Hostnames behind Cloudflare Access."
  value       = module.tunnel.hostnames
}

output "ai_gateway_endpoints" {
  description = "Set ANTHROPIC_BASE_URL / OPENAI_BASE_URL to these in applications."
  value       = module.ai_gateway.provider_endpoints
}

output "log_bucket" {
  description = "S3 bucket with Cloudflare HTTP request and firewall event logs."
  value       = module.logpush.bucket_name
}
