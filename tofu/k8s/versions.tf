# Kubernetes resources, managed by OpenTofu.
#
# SEPARATE state from tofu/ on purpose. The VM configuration and the cluster
# contents have different lifetimes and different failure modes: a mistake here
# must not be able to destroy a VM.
#
# Licence note: hashicorp/kubernetes is MPL-2.0, not BUSL. HashiCorp relicensed
# Terraform core, not its providers, so this does not conflict with decision D2.
# Verified 2026-11-08: github.com/hashicorp/terraform-provider-kubernetes.
terraform {
  required_version = ">= 1.6"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 3.5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.9.1"
    }
  }
}

# Reaches the cluster over Tailscale, by NAME not address.
# The API certificate carries "DNS:mentat" as a subject alternative name, and
# Tailscale MagicDNS resolves it, so TLS verifies with no extra configuration
# and no SSH tunnel. Verified with `openssl s_client`.
provider "kubernetes" {
  config_path = var.kubeconfig
}
