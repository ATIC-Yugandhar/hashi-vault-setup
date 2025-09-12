# =============================================================================
# VAULT JWT AUTHENTICATION FOR GITHUB ACTIONS (MULTI-ENVIRONMENT)
# =============================================================================
# Configure JWT authentication in Vault to work with GitHub Actions OIDC tokens
# Supports multiple environments: dev, prod, staging, etc.
# Based on the actual JWT token structure from GitHub Actions debug output
# =============================================================================

# Vault provider configuration
provider "vault" {
  address = var.vault_server_url
  token   = "vault-dev-root-token"
  
  # Skip TLS verification for dev environment with self-signed certs
  skip_tls_verify = true
}

# Define environments to create roles for
locals {
  environments = ["dev", "prod"]
  operations   = ["plan", "apply"]
}

# Enable JWT auth method
resource "vault_jwt_auth_backend" "github_actions" {
  description        = "JWT auth backend for GitHub Actions OIDC"
  path               = "jwt"
  oidc_discovery_url = "https://token.actions.githubusercontent.com"
  bound_issuer       = "https://token.actions.githubusercontent.com"
}

# Create policy for GitHub Actions with admin permissions
resource "vault_policy" "github_actions" {
  name = "github-actions-admin"

  policy = <<EOT
# Admin policy for GitHub Actions - full access
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
}

# Create JWT roles dynamically for each environment and operation combination
resource "vault_jwt_auth_backend_role" "github_actions" {
  for_each = toset([
    for combo in setproduct(local.environments, local.operations) :
    "${combo[1]}-${combo[0]}"  # Creates: plan-dev, plan-prod, apply-dev, apply-prod
  ])
  
  backend         = vault_jwt_auth_backend.github_actions.path
  role_name       = "tf-github-actions-role-${each.value}"
  token_policies  = [vault_policy.github_actions.name]
  
  # Token configuration - 15 minute TTL
  token_ttl     = 900  # 15 minutes
  token_max_ttl = 900  # 15 minutes maximum
  
  # JWT role configuration based on actual GitHub OIDC token structure
  user_claim = "actor"
  role_type  = "jwt"
  
  # Bound audiences - must match the 'aud' claim in the JWT
  bound_audiences = [
    "https://github.com/${var.github_organization}"
  ]
  
  # Bound claims - must match JWT claims exactly
  bound_claims_type = "string"
  
  # Dynamic subject binding - matches the exact 'sub' claim pattern
  # Format: repo:ATIC-Yugandhar/hashi-vault-setup:environment:tf-plan-dev
  bound_subject = "repo:${var.github_organization}/${var.github_repository}:environment:tf-${each.value}"
  
  # Additional claim mappings for audit and debugging
  claim_mappings = {
    repository = "repository"
    actor      = "actor"
    workflow   = "workflow"
    ref        = "ref"
    environment = "environment"
  }
}