# Scoped API token (Zone WAF/Settings/DNS/Logs edit, Account Tunnel/Access/Lists/AI Gateway edit),
# supplied via TF_VAR_cloudflare_api_token from the CI secret store, never committed.
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
    }
  }
}
