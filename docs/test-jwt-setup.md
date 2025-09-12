# GitHub Actions JWT Auth Testing Guide

## 🔧 Setup Steps

### 1. Configure Terraform Variables
Create a `terraform.tfvars` file with:
```hcl
vault_server_url = "https://your-vault-domain.com:8200"
github_organization = "your-github-org" 
github_repository = "your-repo-name"

# Existing variables
aws_region = "us-west-2"
vault_domain = "your-vault-domain.com"
route53_zone_id = "Z1234567890"
my_ip = "1.2.3.4/32"
environment = "dev"
```

### 2. Deploy JWT Auth to Vault
```bash
# Initialize Terraform with Vault provider
terraform init -upgrade

# Plan the JWT auth configuration
terraform plan -target=vault_policy.github-actions-oidc \
               -target=vault_jwt_auth_backend.jwt \
               -target=vault_jwt_auth_backend_role.github-actions-role-plan \
               -target=vault_jwt_auth_backend_role.github-actions-role-apply

# Apply the JWT auth configuration
terraform apply -target=vault_policy.github-actions-oidc \
                -target=vault_jwt_auth_backend.jwt \
                -target=vault_jwt_auth_backend_role.github-actions-role-plan \
                -target=vault_jwt_auth_backend_role.github-actions-role-apply
```

### 3. Configure GitHub Repository

#### Repository Variables (Settings → Secrets and Variables → Actions):
```
VAULT_ADDR = https://vault.hnytechs.com
AWS_REGION = us-east-1
VAULT_DOMAIN = vault.hnytechs.com
```

**Note**: The GitHub Actions workflows automatically set:
- `github_organization` from `${{ github.repository_owner }}`  
- `github_repository` from `${{ github.event.repository.name }}`
- `vault_server_url` from `VAULT_ADDR` variable

#### Repository Secrets:
```
AWS_ROLE_ARN = arn:aws:iam::account:role/github-actions-role
ROUTE53_ZONE_ID = Z1234567890
MY_IP = 1.2.3.4/32
```

#### Environment Secrets (for both tf-plan-dev and tf-apply-dev environments):
```
TF_STATE_BUCKET = yreddy-tf-state
TF_STATE_KEY = vault-dev/terraform.tfstate
TF_STATE_LOCK_TABLE = terraform-state-lock
```

#### Create Environments:
1. Go to Settings → Environments
2. Create `tf-plan-dev` environment
3. Create `tf-apply-dev` environment
4. Optionally add protection rules (required reviewers, etc.)

## 🧪 Testing Scenarios

### Test 1: PR Workflow (Plan Only)
1. Create a new branch: `git checkout -b test-jwt-auth`
2. Make a small change to a `.tf` file
3. Push and create a Pull Request to main
4. The workflow should:
   - Authenticate with `tf-github-actions-role-plan`
   - Run `terraform fmt -check`
   - Run `terraform validate` 
   - Run `terraform plan`
   - Comment the plan on the PR

### Test 2: Main Branch Workflow (Plan + Apply)
1. Merge the PR to main branch
2. The workflow should:
   - Authenticate with `tf-github-actions-role-apply`
   - Run `terraform plan`
   - Run `terraform apply`
   - Show deployment summary

## 🔍 Troubleshooting

### Common Issues:
1. **OIDC Token Exchange Fails**: Check bound_audiences and bound_subject in JWT roles
2. **Environment Not Found**: Ensure GitHub environments are created
3. **Vault Authentication Fails**: Verify VAULT_ADDR and JWT role names
4. **AWS Credentials**: Ensure AWS_ROLE_ARN exists and has proper trust policy

### Debug Commands:
```bash
# Check JWT auth method
vault auth list

# Check JWT roles  
vault list auth/jwt/role

# Test JWT role directly
vault write auth/jwt/login role=tf-github-actions-role-plan jwt=<github-token>
```

## 📝 Expected Workflow Behavior

### PR Workflow:
- ✅ Triggered on PR to main
- ✅ Uses `tf-plan-dev` environment
- ✅ Gets `tf-github-actions-role-plan` token
- ✅ Runs fmt, validate, plan only
- ✅ Comments plan on PR

### Deploy Workflow:
- ✅ Triggered on push to main
- ✅ Uses `tf-apply-dev` environment  
- ✅ Gets `tf-github-actions-role-apply` token
- ✅ Runs plan and apply
- ✅ Shows deployment summary