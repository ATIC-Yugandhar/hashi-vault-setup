# HashiCorp Vault Development Environment

Automated HashiCorp Vault deployment on AWS with Terraform, featuring GitHub Actions CI/CD, JWT authentication, and comprehensive security configuration.

## 🏗️ Architecture

- **Infrastructure**: Terraform-managed AWS resources (VPC, EC2, Route53, IAM)
- **Vault Server**: Development mode with HTTPS via Let's Encrypt
- **CI/CD**: GitHub Actions with OIDC authentication for secure deployments
- **Authentication**: JWT-based authentication for GitHub Actions → Vault integration
- **State Management**: S3 backend with DynamoDB locking for shared state

## 📁 Repository Structure

```
├── .github/workflows/     # GitHub Actions CI/CD pipelines
│   ├── terraform-deploy.yml   # Deploy on main branch
│   └── terraform-pr.yml       # Validate on pull requests
├── terraform/            # Terraform infrastructure code
│   ├── main.tf              # Main configuration and providers
│   ├── variables.tf         # Input variables
│   ├── outputs.tf           # Output values
│   ├── vpc.tf              # VPC and networking
│   ├── ec2.tf              # EC2 instance configuration
│   ├── dns.tf              # Route53 DNS records
│   ├── vault-jwt-auth.tf   # Vault JWT authentication setup
│   ├── aws-github-oidc.tf  # AWS OIDC provider for GitHub Actions
│   └── ansible-provisioner.tf # Ansible integration
├── ansible/              # Ansible playbooks
│   └── vault-setup.yml      # Vault server configuration
├── scripts/              # Utility scripts
│   ├── sync-github-secrets.sh # Sync secrets to GitHub
│   ├── test-vault-jwt.sh      # Test JWT authentication
│   └── run-ansible.sh         # Manual Ansible execution
└── docs/                 # Documentation
    ├── MANUAL_SETUP_GUIDE.md    # Step-by-step setup guide
    ├── test-jwt-setup.md        # JWT testing documentation
    └── github-secrets-reference.md # GitHub secrets reference
```

## 🚀 Quick Start

### Prerequisites

1. **AWS Account** with programmatic access
2. **Terraform** >= 1.6.0 installed
3. **GitHub CLI** (`gh`) for secrets management
4. **Domain** with Route53 hosted zone
5. **Your public IP** for security group access

### Local Development Setup

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd hashi-vault-setup
   ```

2. **Configure Terraform variables**
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Initialize and apply Terraform**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Sync secrets to GitHub** (for CI/CD)
   ```bash
   cd ../scripts
   ./sync-github-secrets.sh
   ```

### GitHub Actions CI/CD Setup

The repository includes automated CI/CD pipelines:

- **PR Workflow** (`terraform-pr.yml`): Format check, validation, and plan
- **Deploy Workflow** (`terraform-deploy.yml`): Plan and apply on main branch

**Required GitHub Configuration:**

1. **Repository Variables:**
   - `VAULT_ADDR`: Your Vault server URL
   - `VAULT_DOMAIN`: Your Vault domain
   - `AWS_REGION`: AWS region (default: us-east-1)
   - `ENVIRONMENT`: Environment name (default: dev)

2. **Repository Secrets:**
   - `AWS_ROLE_ARN`: AWS OIDC role ARN for GitHub Actions
   - `MY_IP`: Your public IP for security group access
   - `ROUTE53_ZONE_ID`: Route53 hosted zone ID

3. **Environment Secrets** (per environment):
   - `tf-plan-dev` environment for PR workflows
   - `tf-apply-dev` environment for deployment workflows

## 🔧 Configuration

### Terraform Variables

Key variables in `terraform/terraform.tfvars`:

```hcl
# Required
vault_domain      = "vault.yourdomain.com"
route53_zone_id   = "Z1234567890ABC"
my_ip            = "203.0.113.42/32"

# Optional (with defaults)
aws_region       = "us-east-1"
instance_type    = "t3.micro"
vault_version    = "1.15.6"

# GitHub Integration
github_organization = "your-github-org"
github_repository   = "hashi-vault-setup"
vault_server_url   = "https://vault.yourdomain.com"
```

### Security Configuration

- **Network Security**: Restrictive security groups (SSH + Vault access from your IP only)
- **TLS/SSL**: Automatic Let's Encrypt certificates via NGINX
- **Authentication**: JWT-based GitHub Actions authentication
- **State Security**: Encrypted S3 backend with DynamoDB locking

## 🔐 Authentication Flow

1. **GitHub Actions** → **GitHub OIDC Token**
2. **GitHub OIDC Token** → **Vault JWT Authentication**
3. **Vault Token** → **Terraform Operations**
4. **AWS OIDC** → **AWS Temporary Credentials**

## 📚 Documentation

- [Manual Setup Guide](docs/MANUAL_SETUP_GUIDE.md) - Detailed setup instructions
- [JWT Testing Guide](docs/test-jwt-setup.md) - Authentication testing
- [GitHub Secrets Reference](docs/github-secrets-reference.md) - Secrets documentation

## 🛠️ Utility Scripts

- **`scripts/sync-github-secrets.sh`** - Sync local config to GitHub secrets
- **`scripts/test-vault-jwt.sh`** - Test JWT authentication locally
- **`scripts/run-ansible.sh`** - Manual Ansible playbook execution

## 🚦 Workflow

### Development Workflow

1. Create feature branch
2. Make infrastructure changes in `terraform/`
3. Create pull request → triggers validation workflow
4. Review plan output in PR comments
5. Merge to main → triggers deployment workflow

### Production Deployment

1. Update `ENVIRONMENT` variable to `prod`
2. Create `tf-plan-prod` and `tf-apply-prod` environments
3. Configure production-specific secrets
4. Deploy via GitHub Actions or locally

## 🔍 Monitoring & Debugging

- **GitHub Actions**: View workflow logs in Actions tab
- **Terraform State**: Stored in S3 bucket `yreddy-tf-state`
- **Vault Logs**: SSH to EC2 instance and check `/var/log/vault/`
- **SSL Status**: Check Let's Encrypt certificate status

## 🛡️ Security Considerations

- Vault runs in **development mode** - not for production
- Security groups restrict access to your IP only
- All secrets are encrypted in transit and at rest
- GitHub Actions uses short-lived tokens (15-minute TTL)
- AWS access via OIDC (no long-lived keys)

## 🧹 Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

## 🚨 Troubleshooting

### Common Issues

**Certificate Generation Failed:**
```bash
# Check DNS resolution
nslookup vault.yourdomain.com

# Verify Route53 record
aws route53 list-resource-record-sets --hosted-zone-id <your-zone-id>
```

**Vault Not Accessible:**
```bash
# Check if services are running
ssh -i ./vault-ssh-key.pem ubuntu@<ip> "sudo systemctl status vault nginx"

# Check security group allows your IP
cd terraform && terraform plan  # Will show if your IP changed
```

**GitHub Actions Failing:**
- Check repository variables and secrets are set correctly
- Verify GitHub environments exist (`tf-plan-dev`, `tf-apply-dev`)
- Review workflow logs for specific error messages

### Support Commands

```bash
# Test JWT authentication locally
cd scripts && ./test-vault-jwt.sh

# Check Terraform state
cd terraform && terraform show

# Re-sync GitHub secrets
cd scripts && ./sync-github-secrets.sh
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes in `terraform/` directory
4. Test locally and via PR workflow
5. Submit pull request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**⚠️ Important**: This setup is designed for development and testing. For production use, implement proper Vault storage backends, clustering, and enhanced security measures.