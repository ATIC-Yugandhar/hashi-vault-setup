#!/bin/bash

# =============================================================================
# GITHUB ACTIONS SECRETS/VARIABLES SYNC SCRIPT
# =============================================================================
# This script syncs local Terraform variables and AWS configuration 
# to GitHub Actions repository secrets and variables.
#
# Prerequisites:
# 1. GitHub CLI installed and authenticated (gh auth login)
# 2. AWS CLI configured with appropriate credentials
# 3. terraform.tfvars file with local configuration
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_OWNER="ATIC-Yugandhar"
REPO_NAME="hashi-vault-setup"
TFVARS_FILE="terraform.tfvars"

echo -e "${BLUE}🔄 GitHub Actions Secrets/Variables Sync Script${NC}"
echo "=================================================="

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}📋 Checking prerequisites...${NC}"
    
    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}❌ GitHub CLI (gh) is not installed${NC}"
        echo "Install it from: https://cli.github.com/"
        exit 1
    fi
    
    # Check if gh is authenticated
    if ! gh auth status &> /dev/null; then
        echo -e "${RED}❌ GitHub CLI is not authenticated${NC}"
        echo "Run: gh auth login"
        exit 1
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI is not installed${NC}"
        exit 1
    fi
    
    # Check if terraform.tfvars exists
    if [[ ! -f "$TFVARS_FILE" ]]; then
        echo -e "${RED}❌ $TFVARS_FILE file not found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites met${NC}"
}

# Parse terraform.tfvars file
parse_tfvars() {
    echo -e "${YELLOW}📖 Reading $TFVARS_FILE...${NC}"
    
    # Read variables from terraform.tfvars
    VAULT_DOMAIN=$(grep 'vault_domain' $TFVARS_FILE | cut -d'=' -f2 | tr -d ' "')
    ROUTE53_ZONE_ID=$(grep 'route53_zone_id' $TFVARS_FILE | cut -d'=' -f2 | tr -d ' "')
    MY_IP=$(grep 'my_ip' $TFVARS_FILE | cut -d'=' -f2 | tr -d ' "')
    AWS_REGION=$(grep 'aws_region' $TFVARS_FILE | cut -d'=' -f2 | tr -d ' "')
    
    # Construct VAULT_ADDR from vault_domain
    if [[ "$VAULT_DOMAIN" ]]; then
        VAULT_ADDR="https://$VAULT_DOMAIN"
    fi
    
    echo -e "${GREEN}✅ Parsed terraform.tfvars${NC}"
}

# Get AWS IAM role ARN from Terraform output
get_aws_role_arn() {
    echo -e "${YELLOW}🔍 Getting AWS IAM role ARN from Terraform...${NC}"
    
    if command -v terraform &> /dev/null && [[ -f ".terraform/terraform.tfstate" ]] || [[ -f "terraform.tfstate" ]]; then
        AWS_ROLE_ARN=$(terraform output -raw github_actions_role_arn 2>/dev/null || echo "")
        if [[ "$AWS_ROLE_ARN" ]]; then
            echo -e "${GREEN}✅ Found AWS role ARN: $AWS_ROLE_ARN${NC}"
        else
            echo -e "${YELLOW}⚠️  Could not get AWS role ARN from Terraform output${NC}"
            echo "Please make sure Terraform has been applied with the AWS OIDC configuration"
        fi
    else
        echo -e "${YELLOW}⚠️  Terraform not initialized or no state found${NC}"
    fi
}

# Set repository variables
set_repo_variables() {
    echo -e "${YELLOW}🔧 Setting repository variables...${NC}"
    
    # Set VAULT_ADDR
    if [[ "$VAULT_ADDR" ]]; then
        gh variable set VAULT_ADDR --body "$VAULT_ADDR" --repo "$REPO_OWNER/$REPO_NAME"
        echo -e "${GREEN}✅ Set VAULT_ADDR: $VAULT_ADDR${NC}"
    fi
    
    # Set VAULT_DOMAIN  
    if [[ "$VAULT_DOMAIN" ]]; then
        gh variable set VAULT_DOMAIN --body "$VAULT_DOMAIN" --repo "$REPO_OWNER/$REPO_NAME"
        echo -e "${GREEN}✅ Set VAULT_DOMAIN: $VAULT_DOMAIN${NC}"
    fi
    
    # Set AWS_REGION
    if [[ "$AWS_REGION" ]]; then
        gh variable set AWS_REGION --body "$AWS_REGION" --repo "$REPO_OWNER/$REPO_NAME"
        echo -e "${GREEN}✅ Set AWS_REGION: $AWS_REGION${NC}"
    fi
}

# Set repository secrets
set_repo_secrets() {
    echo -e "${YELLOW}🔐 Setting repository secrets...${NC}"
    
    # Set AWS_ROLE_ARN
    if [[ "$AWS_ROLE_ARN" ]]; then
        echo "$AWS_ROLE_ARN" | gh secret set AWS_ROLE_ARN --repo "$REPO_OWNER/$REPO_NAME"
        echo -e "${GREEN}✅ Set AWS_ROLE_ARN (hidden)${NC}"
    fi
    
    # Set ROUTE53_ZONE_ID
    if [[ "$ROUTE53_ZONE_ID" ]]; then
        echo "$ROUTE53_ZONE_ID" | gh secret set ROUTE53_ZONE_ID --repo "$REPO_OWNER/$REPO_NAME"
        echo -e "${GREEN}✅ Set ROUTE53_ZONE_ID (hidden)${NC}"
    fi
    
    # Set MY_IP
    if [[ "$MY_IP" ]]; then
        echo "$MY_IP" | gh secret set MY_IP --repo "$REPO_OWNER/$REPO_NAME"
        echo -e "${GREEN}✅ Set MY_IP (hidden)${NC}"
    fi
}

# Set environment secrets for tf-plan-dev and tf-apply-dev
set_environment_secrets() {
    local env_name=$1
    echo -e "${YELLOW}🌍 Setting $env_name environment secrets...${NC}"
    
    # Set TF_STATE_BUCKET
    echo "yreddy-tf-state" | gh secret set TF_STATE_BUCKET --env "$env_name" --repo "$REPO_OWNER/$REPO_NAME"
    echo -e "${GREEN}✅ Set TF_STATE_BUCKET for $env_name${NC}"
    
    # Set TF_STATE_KEY
    echo "vault-dev/terraform.tfstate" | gh secret set TF_STATE_KEY --env "$env_name" --repo "$REPO_OWNER/$REPO_NAME"
    echo -e "${GREEN}✅ Set TF_STATE_KEY for $env_name${NC}"
    
    # Set TF_STATE_LOCK_TABLE (commented out in current config)
    echo "terraform-state-lock" | gh secret set TF_STATE_LOCK_TABLE --env "$env_name" --repo "$REPO_OWNER/$REPO_NAME"
    echo -e "${GREEN}✅ Set TF_STATE_LOCK_TABLE for $env_name${NC}"
}

# Create environments if they don't exist
create_environments() {
    echo -e "${YELLOW}🏗️  Creating GitHub environments...${NC}"
    
    # Note: GitHub CLI doesn't have direct environment creation commands
    # This is a placeholder - environments need to be created via GitHub UI or API
    echo -e "${BLUE}ℹ️  Please ensure these environments exist in GitHub:${NC}"
    echo "   - tf-plan-dev"
    echo "   - tf-apply-dev"
    echo ""
    echo "Create them at: https://github.com/$REPO_OWNER/$REPO_NAME/settings/environments"
}

# Update local reference file
update_reference_file() {
    echo -e "${YELLOW}📝 Updating local secrets reference file...${NC}"
    
    cat > github-secrets-reference.md << EOF
# GitHub Actions Secrets & Variables Reference

This file contains all the GitHub Actions secrets and variables configuration for reference.
**IMPORTANT: This file is excluded from git via .gitignore for security reasons.**

## 🔧 Repository Variables (Public - visible in logs)

| Variable Name | Value | Purpose |
|---------------|-------|---------|
| \`AWS_REGION\` | \`$AWS_REGION\` | AWS region for resource deployment |
| \`VAULT_ADDR\` | \`$VAULT_ADDR\` | Vault server address |
| \`VAULT_DOMAIN\` | \`$VAULT_DOMAIN\` | Vault domain name |

## 🔐 Repository Secrets (Hidden values)

| Secret Name | Value | Purpose |
|-------------|-------|---------|
| \`AWS_ROLE_ARN\` | \`$AWS_ROLE_ARN\` | AWS OIDC role for GitHub Actions authentication |
| \`MY_IP\` | \`$MY_IP\` | Your public IP address for security group access |
| \`ROUTE53_ZONE_ID\` | \`$ROUTE53_ZONE_ID\` | Route53 hosted zone ID for DNS records |

## 🌍 Environment Secrets - tf-plan-dev

| Secret Name | Value | Purpose |
|-------------|-------|---------|
| \`TF_STATE_BUCKET\` | \`yreddy-tf-state\` | S3 bucket name for Terraform state storage |
| \`TF_STATE_KEY\` | \`vault-dev/terraform.tfstate\` | S3 object key for state file |
| \`TF_STATE_LOCK_TABLE\` | \`terraform-state-lock\` | DynamoDB table for state locking |

## 🌍 Environment Secrets - tf-apply-dev

| Secret Name | Value | Purpose |
|-------------|-------|---------|
| \`TF_STATE_BUCKET\` | \`yreddy-tf-state\` | S3 bucket name for Terraform state storage |
| \`TF_STATE_KEY\` | \`vault-dev/terraform.tfstate\` | S3 object key for state file |
| \`TF_STATE_LOCK_TABLE\` | \`terraform-state-lock\` | DynamoDB table for state locking |

## 🔄 Auto-Generated Variables in GitHub Actions

These variables are automatically populated by GitHub Actions workflows:

| Variable Name | GitHub Context | Resolved Value | Purpose |
|---------------|----------------|----------------|---------|
| \`TF_VAR_github_organization\` | \`\${{ github.repository_owner }}\` | \`$REPO_OWNER\` | GitHub organization name |
| \`TF_VAR_github_repository\` | \`\${{ github.event.repository.name }}\` | \`$REPO_NAME\` | GitHub repository name |
| \`TF_VAR_vault_server_url\` | \`\${{ vars.VAULT_ADDR }}\` | \`$VAULT_ADDR\` | Vault server URL |

---

**Last Updated:** \$(date)
**Generated by:** sync-github-secrets.sh
EOF
    
    echo -e "${GREEN}✅ Updated github-secrets-reference.md${NC}"
}

# Display summary
display_summary() {
    echo ""
    echo -e "${BLUE}📊 Configuration Summary${NC}"
    echo "========================="
    echo -e "Repository: ${GREEN}$REPO_OWNER/$REPO_NAME${NC}"
    echo -e "Vault Domain: ${GREEN}${VAULT_DOMAIN:-'Not set'}${NC}"
    echo -e "Vault Address: ${GREEN}${VAULT_ADDR:-'Not set'}${NC}"
    echo -e "AWS Region: ${GREEN}${AWS_REGION:-'Not set'}${NC}"
    echo -e "Route53 Zone: ${GREEN}${ROUTE53_ZONE_ID:-'Not set'}${NC}"
    echo -e "My IP: ${GREEN}${MY_IP:-'Not set'}${NC}"
    echo -e "AWS Role ARN: ${GREEN}${AWS_ROLE_ARN:-'Not found - run terraform apply first'}${NC}"
    echo ""
    echo -e "${GREEN}🎉 GitHub Actions configuration sync completed!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Ensure environments tf-plan-dev and tf-apply-dev exist"
    echo "2. Test by creating a PR with Terraform changes"
    echo "3. Check GitHub Actions workflow logs"
    echo "4. Local reference file updated: github-secrets-reference.md"
}

# Main execution
main() {
    check_prerequisites
    parse_tfvars
    get_aws_role_arn
    set_repo_variables
    set_repo_secrets
    create_environments
    set_environment_secrets "tf-plan-dev"
    set_environment_secrets "tf-apply-dev"
    update_reference_file
    display_summary
}

# Run main function
main "$@"