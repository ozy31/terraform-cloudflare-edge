output "tunnel_id" {
  description = "Cloudflare Tunnel ID."
  value       = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

output "hostnames" {
  description = "Published hostnames by service."
  value       = { for k, s in var.services : k => s.hostname }
}

output "access_aud_tags" {
  description = "Access application AUD tags by service (for origin-side JWT validation)."
  value       = { for k, app in cloudflare_zero_trust_access_application.this : k => app.aud }
}

output "service_tokens" {
  description = "Access service token credentials by service. Machine clients send CF-Access-Client-Id and CF-Access-Client-Secret headers."
  sensitive   = true
  value = {
    for k, t in cloudflare_zero_trust_access_service_token.this : k => {
      client_id     = t.client_id
      client_secret = t.client_secret
    }
  }
}
