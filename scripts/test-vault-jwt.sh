#!/bin/bash

# Test script to verify Vault JWT authentication setup
# Usage: ./test-vault-jwt.sh

set -e

VAULT_ADDR=${VAULT_ADDR:-"https://your-vault-domain.com"}
VAULT_TOKEN=${VAULT_TOKEN:-"vault-dev-root-token"}

echo "🔍 Testing Vault JWT Authentication Setup..."
echo "Vault Address: $VAULT_ADDR"

# Check if Vault is accessible
echo "1. Checking Vault accessibility..."
vault status

# Check JWT auth method
echo "2. Checking JWT auth method..."
vault auth list | grep jwt || echo "❌ JWT auth method not found"

# List JWT roles
echo "3. Listing JWT roles..."
vault list auth/jwt/role || echo "❌ No JWT roles found"

# Check specific roles exist
echo "4. Checking specific roles..."
vault read auth/jwt/role/tf-github-actions-role-plan || echo "❌ Plan role not found"
vault read auth/jwt/role/tf-github-actions-role-apply || echo "❌ Apply role not found"

# Check policy exists
echo "5. Checking policy..."
vault policy read github-actions-oidc || echo "❌ Policy not found"

echo "✅ Vault JWT setup verification complete!"
echo ""
echo "Next steps:"
echo "1. Configure GitHub repository variables and secrets"
echo "2. Create GitHub environments: tf-plan-dev, tf-apply-dev"
echo "3. Test by creating a PR with .tf file changes"