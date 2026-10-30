terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59, < 7.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.28, < 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0, < 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6, < 4.0"
    }
  }
}
