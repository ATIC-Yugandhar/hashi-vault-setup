# =============================================================================
# VAULT JWT AUTHENTICATION FOR GITLAB CI/CD Pipeline
# =============================================================================
# Configure JWT authentication in Vault to work with Gitlab CI/CD Pipleine
# Supports multiple branches: main, release, development, etc.
# =============================================================================

# Enable JWT auth method
resource "vault_jwt_auth_backend" "gitlab_pipeline" {
  description        = "JWT auth backend for Gitlab CI/CD Pipeline"
  path               = "jwt-gitlab"
  oidc_discovery_url = "https://gitlab.com"
  bound_issuer       = "https://gitlab.com"
}

# Create policy for Gitlab CI/CD Pipeline with read permissions
resource "vault_policy" "gitlabci_policy" {
  name = "gitlab-ci"

  policy = <<EOT
# Admin policy for GitHub Actions - full access
path "secret/data/gitlab/*" {
  capabilities = ["read"]
}
EOT
}

# Create JWT roles dynamically for each environment and operation combination
resource "vault_jwt_auth_backend_role" "gitlabci_role" {

  backend        = vault_jwt_auth_backend.gitlab_pipeline.path
  role_name      = "gitlabci-role"
  token_policies = [vault_policy.gitlabci_policy.name]

  # Token configuration - 15 minute TTL
  token_ttl     = 600 # 10 minutes
  token_max_ttl = 900 # 15 minutes maximum

  # JWT role configuration based on actual Gitlab token structure
  user_claim = "sub"
  role_type  = "jwt"

  # Bound audiences - must match the 'aud' claim in the JWT
  bound_audiences = [
    "https://gitlab.com",
    "gitlab.com"
  ]

  # Bound claims - must match JWT claims exactly
  bound_claims = {
    project_id = "74331448",
    ref        = "main",
    ref_type   = "branch"
  }
  # Additional claim mappings for audit and debugging
  claim_mappings = {
    repository  = "project_path",
    actor       = "user_login"
    workflow    = "pipeline_id"
    ref         = "ref"
    environment = "environment"
  }
}