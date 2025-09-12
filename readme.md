# HashiCorp Vault Development Environment

Terraform configuration to deploy a secure HashiCorp Vault development server on AWS with HTTPS support using Let's Encrypt certificates.

## 🏗️ Architecture

- **EC2 Instance**: Single t3.micro instance running Ubuntu 22.04
- **Vault**: Development mode with in-memory storage
- **Security**: NGINX reverse proxy with Let's Encrypt SSL/TLS certificates
- **Network**: Custom VPC with public subnet and restrictive security groups
- **DNS**: Route53 A record for custom domain access

## 🚀 Quick Start

### Prerequisites

1. **AWS Account** with programmatic access configured
2. **Terraform** >= 1.0 installed
3. **AWS CLI** configured with appropriate permissions
4. **Domain** with Route53 hosted zone (required for SSL certificates)
5. **Your public IP address** in CIDR format

### Required AWS Permissions

Your AWS credentials need the following permissions:
- EC2 (instances, VPC, security groups, key pairs)
- Route53 (hosted zones, DNS records)
- Systems Manager (Parameter Store) - optional

### Step 1: Clone and Configure

```bash
git clone <repository-url>
cd hashi-vault-setup
```

### Step 2: Create Configuration File

Create `terraform.tfvars` with your specific values:

```hcl
# Required Variables
vault_domain      = "vault.yourdomain.com"    # Your vault subdomain
route53_zone_id   = "Z1234567890ABC"          # Your Route53 zone ID
my_ip            = "203.0.113.42/32"          # Your public IP in CIDR format

# Optional Variables (defaults shown)
aws_region       = "us-west-2"
instance_type    = "t3.micro"
vault_version    = "1.15.6"
environment      = "dev"
```

### Step 3: Get Your Public IP

```bash
# Get your current public IP
curl -s https://checkip.amazonaws.com
# Add /32 to the end for CIDR format: e.g., 203.0.113.42/32
```

### Step 4: Find Your Route53 Zone ID

```bash
# List your hosted zones
aws route53 list-hosted-zones --query 'HostedZones[*].[Name,Id]' --output table
```

### Step 5: Deploy Infrastructure (Fully Automated)

```bash
# Initialize Terraform
terraform init

# Plan deployment (optional)
terraform plan

# Deploy everything automatically - Terraform + Ansible integration
terraform apply -auto-approve
```

**What happens automatically:**
- Terraform deploys AWS infrastructure (VPC, EC2, Route53, etc.)
- Dynamic inventory automatically provides current IP and configuration to Ansible
- Ansible automatically configures Vault with HTTPS
- Let's Encrypt certificate is obtained and configured
- NGINX reverse proxy is set up with security headers
- Automatic certificate renewal is configured

### Step 6: Access Your Vault

After deployment completes (takes ~3-5 minutes), everything is ready to use:

```bash
# Connection details are displayed automatically, or check:
terraform output vault_url
terraform output vault_login_instructions

# Check the completion summary (generated locally after deployment)
cat SETUP_COMPLETE.md
```

**Note**: `SETUP_COMPLETE.md` is automatically generated after deployment and contains sensitive information (IP addresses, tokens), so it's excluded from git for security.

**Web UI Access:**
- URL: `https://vault.yourdomain.com`
- Token: `vault-dev-root-token`

**CLI Access:**
```bash
export VAULT_ADDR=https://vault.yourdomain.com
export VAULT_TOKEN=vault-dev-root-token
vault status
```

## 🔧 Configuration Options

### Variables Reference

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `vault_domain` | FQDN for Vault access | - | ✅ |
| `route53_zone_id` | Route53 hosted zone ID | - | ✅ |
| `my_ip` | Your IP in CIDR format | - | ✅ |
| `aws_region` | AWS deployment region | `us-west-2` | ❌ |
| `instance_type` | EC2 instance type | `t3.micro` | ❌ |
| `vault_version` | Vault version to install | `1.15.6` | ❌ |
| `environment` | Environment tag | `dev` | ❌ |
| `store_ssh_key_in_ssm` | Store SSH keys in Parameter Store | `true` | ❌ |

### Security Features

- **IP Restriction**: Access limited to your IP address only
- **HTTPS Only**: Let's Encrypt certificates with automatic renewal
- **Security Headers**: HSTS, X-Frame-Options, Content-Type-Options
- **SSH Keys**: Generated automatically and stored locally/SSM
- **Network Security**: Custom VPC with minimal access rules

## 📋 Outputs

After deployment, you'll receive:

- **vault_url**: HTTPS URL for Vault access
- **ssh_command**: Ready-to-use SSH command
- **vault_login_instructions**: Complete setup instructions
- **ec2_public_ip**: Instance public IP address

## 🔐 SSH Access

```bash
# SSH into the instance
ssh -i ./vault-ssh-key.pem ubuntu@<instance-ip>

# Check Vault status
sudo systemctl status vault

# Check NGINX status
sudo systemctl status nginx

# View Vault logs
sudo journalctl -u vault -f
```

## 🔄 Management Commands

### Certificate Management
```bash
# Check certificate status
sudo certbot certificates

# Manual certificate renewal
sudo certbot renew

# Test renewal process
sudo certbot renew --dry-run
```

### Service Management
```bash
# Restart services
sudo systemctl restart vault
sudo systemctl restart nginx

# Check service status
sudo systemctl status vault nginx
```

## 🧹 Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Note**: This will permanently delete your Vault instance and all data.

## 🚨 Security Considerations

### Development Use Only
- Uses Vault dev mode with in-memory storage
- Root token is static and exposed in outputs
- Data is not persisted between restarts

### Production Recommendations
- Use Vault production mode with encrypted storage
- Implement proper authentication methods
- Use auto-unsealing with AWS KMS
- Enable audit logging
- Use load balancers for high availability

### Network Security
- Access restricted to your IP address only
- HTTPS enforced with security headers
- SSH access limited to your IP
- All outbound traffic allowed for updates

## 🔧 Troubleshooting

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
terraform plan  # Will show if your IP changed
```

**SSH Connection Failed:**
- Verify your IP hasn't changed
- Check key file permissions: `chmod 600 ./vault-ssh-key.pem`
- Ensure security group allows SSH from your IP

### Support Commands

```bash
# Check if setup script ran automatically
ssh -i ./vault-ssh-key.pem ubuntu@<ip> "sudo cat /var/log/vault-setup.log"

# Check cloud-init logs
ssh -i ./vault-ssh-key.pem ubuntu@<ip> "sudo cat /var/log/cloud-init-output.log"

# Re-run setup script manually if needed
ssh -i ./vault-ssh-key.pem ubuntu@<ip> "sudo /tmp/vault-setup.sh"

# Test NGINX configuration
ssh -i ./vault-ssh-key.pem ubuntu@<ip> "sudo nginx -t"
```

### Known Issues

**Cloud-init runcmd Module Skipping (Ubuntu 22.04)**
- **Issue**: Cloud-init may skip the `runcmd` module on some Ubuntu 22.04 instances
- **Workaround**: Use the manual setup steps or re-run `/tmp/vault-setup.sh`
- **Fixed**: Updated user-data.yml to use `write_files` + `runcmd` for better reliability

## 📄 License

This project is provided as-is for development and learning purposes.

## 🤝 Contributing

Feel free to submit issues and enhancement requests.