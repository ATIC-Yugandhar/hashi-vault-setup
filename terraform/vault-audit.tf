# =============================================================================
# VAULT AUDIT LOGGING CONFIGURATION
# =============================================================================
# Configure audit logging for Vault development environment
# Audit logs provide detailed information about all Vault operations
# =============================================================================

# Enable file audit device for comprehensive logging
resource "vault_audit" "file_audit" {
  type = "file"
  path = "audit_file"

  options = {
    file_path = "/var/log/vault/audit.log"
    # Log all requests and responses (including sensitive data in dev)
    log_raw = "true"
    # HMAC sensitive values in production, but disable for dev visibility
    hmac_accessor     = "false"
    # Format as JSON for easier parsing
    format           = "json"
    # Enable prefix for easier log identification
    prefix           = "vault_audit"
  }

  depends_on = [vault_jwt_auth_backend.github_actions]
}

# Optional: Enable stdout audit device for immediate visibility
resource "vault_audit" "stdout_audit" {
  count = var.enable_stdout_audit ? 1 : 0
  type  = "file"
  path  = "audit_stdout"

  options = {
    file_path = "stdout"
    log_raw   = "false"
    format    = "json"
    prefix    = "vault_stdout"
  }

  depends_on = [vault_jwt_auth_backend.github_actions]
}