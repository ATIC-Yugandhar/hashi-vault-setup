#!/bin/bash

# =============================================================================
# GITHUB ACTIONS SINGLE SECRET UPDATE SCRIPT
# =============================================================================
# Quick script to update individual GitHub Actions secrets/variables
#
# Usage:
#   ./update-github-secret.sh variable VAULT_ADDR "https://vault.example.com"
#   ./update-github-secret.sh secret MY_IP "1.2.3.4/32"
#   ./update-github-secret.sh env-secret tf-plan-dev TF_STATE_BUCKET "my-bucket"
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
REPO_OWNER="ATIC-Yugandhar"
REPO_NAME="hashi-vault-setup"

# Usage function
usage() {
    echo "Usage: $0 <type> [environment] <name> <value>"
    echo ""
    echo "Types:"
    echo "  variable      - Set repository variable"
    echo "  secret        - Set repository secret"
    echo "  env-secret    - Set environment secret (requires environment name)"
    echo ""
    echo "Examples:"
    echo "  $0 variable VAULT_ADDR 'https://vault.example.com'"
    echo "  $0 secret AWS_ROLE_ARN 'arn:aws:iam::123:role/github-actions'"
    echo "  $0 env-secret tf-plan-dev TF_STATE_BUCKET 'my-tf-state-bucket'"
    exit 1
}

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed${NC}"
    exit 1
fi

# Parse arguments
if [[ $# -lt 3 ]]; then
    usage
fi

TYPE=$1

case $TYPE in
    "variable")
        if [[ $# -ne 3 ]]; then
            usage
        fi
        NAME=$2
        VALUE=$3
        gh variable set "$NAME" --body "$VALUE" --repo "$REPO_OWNER/$REPO_NAME"
        echo -e "${GREEN}✅ Set variable $NAME${NC}"
        ;;
    
    "secret")
        if [[ $# -ne 3 ]]; then
            usage
        fi
        NAME=$2
        VALUE=$3
        echo "$VALUE" | gh secret set "$NAME" --repo "$REPO_OWNER/$REPO_NAME"
        echo -e "${GREEN}✅ Set secret $NAME (hidden)${NC}"
        ;;
    
    "env-secret")
        if [[ $# -ne 4 ]]; then
            usage
        fi
        ENV_NAME=$2
        NAME=$3
        VALUE=$4
        echo "$VALUE" | gh secret set "$NAME" --env "$ENV_NAME" --repo "$REPO_OWNER/$REPO_NAME"
        echo -e "${GREEN}✅ Set environment secret $NAME for $ENV_NAME (hidden)${NC}"
        ;;
    
    *)
        echo -e "${RED}❌ Invalid type: $TYPE${NC}"
        usage
        ;;
esac