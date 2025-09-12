# Manual HashiCorp Vault Setup with NGINX & Let's Encrypt

This guide documents the exact steps taken to manually set up HashiCorp Vault with NGINX reverse proxy and Let's Encrypt SSL certificates on Ubuntu 22.04. This is for learning purposes and understanding what happens behind the scenes.

## 📚 Learning Objectives

After following this guide, you'll understand:
- How to install and configure HashiCorp Vault in development mode
- Setting up NGINX as a reverse proxy for HTTPS termination
- Obtaining and configuring Let's Encrypt SSL certificates with Certbot
- Managing systemd services for Vault and NGINX
- Troubleshooting common SSL/TLS configuration issues

## 🏗️ Architecture Overview

```
Internet → Route53 DNS → EC2 Public IP → NGINX (443/80) → Vault (8200)
                                    ↓
                             Let's Encrypt Certificate
```

- **Port 80**: HTTP redirect to HTTPS + Let's Encrypt ACME challenges
- **Port 443**: NGINX HTTPS termination → proxy to Vault on localhost:8200
- **Port 8200**: Vault development server (localhost only)

## 🚀 Prerequisites

1. **Ubuntu 22.04 EC2 Instance** with:
   - Security group allowing ports 22, 80, 443 from your IP
   - Security group allowing port 80 from 0.0.0.0/0 (Let's Encrypt validation)
   - Public IP address
   
2. **Domain Configuration**:
   - Domain name pointing to EC2 public IP (A record)
   - Route53 or any DNS provider

3. **System Updates**:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

**💡 When to Use This Guide:**
- When Terraform cloud-init automation fails or needs manual verification
- For learning the complete setup process step-by-step  
- For troubleshooting existing deployments
- For adapting to different cloud providers or configurations

## 📋 Step-by-Step Setup

### Step 1: Install Required Packages

```bash
# Update package repositories
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y unzip curl jq snapd nginx

# Enable and start snapd (required for Certbot)
sudo systemctl enable snapd
sudo systemctl start snapd
```

### Step 2: Create Vault User and Directories

```bash
# Create system user for Vault (no shell access)
sudo useradd --system --home /etc/vault --shell /bin/false vault

# Create required directories
sudo mkdir -p /opt/vault/data /etc/vault/tls /var/log/vault

# Set proper ownership
sudo chown -R vault:vault /opt/vault /etc/vault /var/log/vault
```

### Step 3: Download and Install Vault

```bash
# Set Vault version (use latest stable version)
VAULT_VERSION="1.15.6"

# Download Vault binary
cd /tmp
curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip" -o vault.zip

# Verify download (optional but recommended)
# curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS" -o vault_checksums.txt
# grep "vault_${VAULT_VERSION}_linux_amd64.zip" vault_checksums.txt | sha256sum -c

# Extract and install
unzip -q vault.zip
sudo chmod +x vault
sudo mv vault /usr/local/bin/

# Verify installation
vault --version
```

### Step 4: Create Vault Systemd Service

Create the service configuration:

```bash
sudo tee /etc/systemd/system/vault.service > /dev/null << 'EOF'
[Unit]
Description=HashiCorp Vault (Development Mode)
Documentation=https://developer.hashicorp.com/vault/docs
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=vault
Group=vault
ExecStart=/usr/local/bin/vault server -dev -dev-listen-address=127.0.0.1:8200 -dev-root-token-id=vault-dev-root-token
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF
```

**Important Notes about the Service:**
- `User=vault`: Runs as dedicated vault user for security
- `ExecStart`: Development mode with fixed root token for simplicity
- `dev-listen-address=127.0.0.1:8200`: Only listens on localhost for security
- `LimitMEMLOCK=infinity`: Allows Vault to lock memory pages
- `Restart=on-failure`: Automatically restarts if service fails

### Step 5: Start and Enable Vault Service

```bash
# Reload systemd to recognize new service
sudo systemctl daemon-reload

# Enable service to start on boot
sudo systemctl enable vault

# Start Vault service
sudo systemctl start vault

# Check service status
sudo systemctl status vault

# Wait a moment for Vault to fully start
sleep 5

# Verify Vault is running
curl -s http://127.0.0.1:8200/v1/sys/health | jq .
```

Expected output should show Vault is running and unsealed.

### Step 6: Install Certbot for Let's Encrypt

```bash
# Install certbot via snap (recommended method)
sudo snap install core
sudo snap refresh core
sudo snap install --classic certbot

# Create symlink for easier access
sudo ln -sf /snap/bin/certbot /usr/bin/certbot

# Verify installation
certbot --version
```

### Step 7: Configure NGINX for HTTP (Preparation for HTTPS)

First, create a basic NGINX configuration to serve HTTP and handle Let's Encrypt challenges:

```bash
# Remove default NGINX site
sudo rm -f /etc/nginx/sites-enabled/default

# Set your domain (replace with your actual domain)
VAULT_DOMAIN="vault.yourdomain.com"

# Create initial NGINX configuration for HTTP only
sudo tee /etc/nginx/sites-available/vault > /dev/null << EOF
server {
    listen 80;
    server_name ${VAULT_DOMAIN};
    
    # Let's Encrypt ACME challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Temporary: serve Vault directly over HTTP for initial setup
    location / {
        proxy_pass http://127.0.0.1:8200;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/vault /etc/nginx/sites-enabled/

# Test NGINX configuration
sudo nginx -t

# Start and enable NGINX
sudo systemctl enable nginx
sudo systemctl start nginx

# Check NGINX status
sudo systemctl status nginx
```

### Step 8: Obtain Let's Encrypt Certificate

```bash
# Create webroot directory for Let's Encrypt challenges
sudo mkdir -p /var/www/html
sudo chown -R www-data:www-data /var/www/html

# Set your domain and email
VAULT_DOMAIN="vault.yourdomain.com"
EMAIL="admin@yourdomain.com"  # Change to your email

# Request Let's Encrypt certificate
sudo certbot certonly --webroot \
  --webroot-path /var/www/html \
  --email "${EMAIL}" \
  --agree-tos \
  --no-eff-email \
  --domains "${VAULT_DOMAIN}" \
  --non-interactive

# Verify certificate was created
sudo ls -la /etc/letsencrypt/live/${VAULT_DOMAIN}/
```

Expected files:
- `cert.pem`: The certificate
- `chain.pem`: The certificate chain
- `fullchain.pem`: Certificate + chain (use this for NGINX)
- `privkey.pem`: Private key

### Step 9: Update NGINX Configuration for HTTPS

Now update NGINX to use the SSL certificate and enforce HTTPS:

```bash
# Create HTTPS-enabled NGINX configuration
sudo tee /etc/nginx/sites-available/vault > /dev/null << EOF
# HTTP server - redirects to HTTPS and serves ACME challenges
server {
    listen 80;
    server_name ${VAULT_DOMAIN};
    
    # Let's Encrypt ACME challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirect all other HTTP traffic to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS server - main Vault proxy
server {
    listen 443 ssl http2;
    server_name ${VAULT_DOMAIN};
    
    # SSL Certificate Configuration
    ssl_certificate /etc/letsencrypt/live/${VAULT_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${VAULT_DOMAIN}/privkey.pem;
    
    # Modern SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Proxy Configuration for Vault
    location / {
        proxy_pass http://127.0.0.1:8200;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Buffer settings for better performance
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }
}
EOF

# Test the new configuration
sudo nginx -t

# Reload NGINX to apply changes
sudo systemctl reload nginx
```

### Step 10: Set Up Automatic Certificate Renewal

```bash
# Create a renewal script that also reloads NGINX
sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh > /dev/null << 'EOF'
#!/bin/bash
systemctl reload nginx
EOF

# Make the script executable
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

# Add cron job for automatic renewal (runs daily at noon)
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -

# Test the renewal process (dry run)
sudo certbot renew --dry-run
```

### Step 11: Verify Complete Setup

Test all components to ensure everything is working:

```bash
# 1. Check Vault service
sudo systemctl status vault --no-pager

# 2. Check NGINX service
sudo systemctl status nginx --no-pager

# 3. Test Vault locally
curl -s http://127.0.0.1:8200/v1/sys/health | jq .

# 4. Test HTTPS redirect
curl -I http://${VAULT_DOMAIN}

# 5. Test HTTPS access
curl -I https://${VAULT_DOMAIN}

# 6. Check SSL certificate
openssl s_client -connect ${VAULT_DOMAIN}:443 -servername ${VAULT_DOMAIN} </dev/null 2>/dev/null | openssl x509 -noout -dates

# 7. Test Vault UI access
curl -k -s https://${VAULT_DOMAIN}/ui/ | grep -o '<title>[^<]*</title>'
```

## 🔧 Configuration Deep Dive

### NGINX Proxy Settings Explained

```nginx
# Essential proxy headers for proper functionality
proxy_set_header Host $host;                    # Preserves original Host header
proxy_set_header X-Real-IP $remote_addr;       # Client's real IP address
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; # IP forwarding chain
proxy_set_header X-Forwarded-Proto $scheme;    # Original protocol (https)

# WebSocket support (important for Vault UI)
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

### Security Headers Explained

```nginx
# HSTS: Forces HTTPS for 1 year
add_header Strict-Transport-Security "max-age=31536000" always;

# Prevents embedding in frames (clickjacking protection)
add_header X-Frame-Options DENY always;

# Prevents MIME type sniffing
add_header X-Content-Type-Options nosniff always;

# XSS protection (legacy but still useful)
add_header X-XSS-Protection "1; mode=block" always;

# Referrer policy for privacy
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

### Vault Development Mode Limitations

**⚠️ Important: Development Mode is NOT for Production**

- **In-Memory Storage**: All data lost on restart
- **Auto-Unsealing**: No seal/unseal process
- **Fixed Root Token**: Security risk in production
- **No High Availability**: Single point of failure
- **No Audit Logging**: No audit trail by default

## 🔍 Troubleshooting Guide

### Common Issues and Solutions

#### 1. Vault Service Won't Start

```bash
# Check Vault service logs
sudo journalctl -u vault -f

# Common issues:
# - Port 8200 already in use
sudo netstat -tlnp | grep 8200

# - Permission issues
sudo chown -R vault:vault /opt/vault /etc/vault /var/log/vault
```

#### 2. NGINX SSL Configuration Errors

```bash
# Test NGINX configuration
sudo nginx -t

# Check SSL certificate files exist and have correct permissions
sudo ls -la /etc/letsencrypt/live/${VAULT_DOMAIN}/
sudo chmod 644 /etc/letsencrypt/live/${VAULT_DOMAIN}/*.pem
sudo chmod 600 /etc/letsencrypt/live/${VAULT_DOMAIN}/privkey.pem
```

#### 3. Let's Encrypt Certificate Issues

```bash
# Check certificate status
sudo certbot certificates

# View certificate details
sudo certbot show_account

# Check DNS resolution
nslookup ${VAULT_DOMAIN}
dig ${VAULT_DOMAIN}

# Test HTTP-01 challenge manually
curl -I http://${VAULT_DOMAIN}/.well-known/acme-challenge/test
```

#### 4. Access Issues

```bash
# Check if ports are accessible
# From the EC2 instance:
sudo netstat -tlnp | grep -E "(80|443|8200)"

# Test local connectivity
curl -I http://127.0.0.1:8200
curl -I https://127.0.0.1:443

# Check security group rules in AWS console
```

#### 5. Certificate Renewal Problems

```bash
# Check cron job
sudo crontab -l

# Test renewal manually
sudo certbot renew --force-renewal

# Check renewal logs
sudo tail -f /var/log/letsencrypt/letsencrypt.log
```

### Performance Tuning

#### NGINX Buffer Optimization

```nginx
# Add to location block in NGINX config
proxy_buffering on;
proxy_buffer_size 128k;
proxy_buffers 4 256k;
proxy_busy_buffers_size 256k;
proxy_max_temp_file_size 1024m;
```

#### Vault Memory Settings

```bash
# For production use, add to systemd service:
# LimitNOFILE=1048576
# LimitMEMLOCK=infinity

# Check current limits
sudo -u vault bash -c 'ulimit -a'
```

## 🔐 Security Best Practices

### File Permissions

```bash
# Vault directories
sudo chmod 755 /opt/vault
sudo chmod 750 /opt/vault/data
sudo chmod 640 /etc/vault/*

# SSL certificates
sudo chmod 644 /etc/letsencrypt/live/${VAULT_DOMAIN}/fullchain.pem
sudo chmod 600 /etc/letsencrypt/live/${VAULT_DOMAIN}/privkey.pem
```

### Network Security

```bash
# Verify Vault only listens on localhost
sudo netstat -tlnp | grep 8200
# Should show: 127.0.0.1:8200

# Check NGINX is listening on all interfaces for 80/443
sudo netstat -tlnp | grep nginx
# Should show: 0.0.0.0:80 and 0.0.0.0:443
```

### Service Hardening

```bash
# Enable UFW firewall (optional, EC2 security groups preferred)
sudo ufw --force enable
sudo ufw allow from YOUR_IP_ADDRESS to any port 22
sudo ufw allow 80
sudo ufw allow 443
```

## 📊 Monitoring and Logging

### Service Status Monitoring

```bash
# Create a simple health check script
sudo tee /usr/local/bin/vault-health-check.sh > /dev/null << 'EOF'
#!/bin/bash
echo "=== Vault Health Check ===="
echo "Vault Service: $(systemctl is-active vault)"
echo "NGINX Service: $(systemctl is-active nginx)"
echo "Vault Health: $(curl -s http://127.0.0.1:8200/v1/sys/health | jq -r .initialized)"
echo "SSL Certificate Expiry: $(openssl s_client -connect ${VAULT_DOMAIN}:443 -servername ${VAULT_DOMAIN} </dev/null 2>/dev/null | openssl x509 -noout -enddate)"
EOF

sudo chmod +x /usr/local/bin/vault-health-check.sh

# Run health check
sudo /usr/local/bin/vault-health-check.sh
```

### Log Locations

```bash
# Vault logs
sudo journalctl -u vault -f

# NGINX access logs
sudo tail -f /var/log/nginx/access.log

# NGINX error logs
sudo tail -f /var/log/nginx/error.log

# Let's Encrypt logs
sudo tail -f /var/log/letsencrypt/letsencrypt.log

# Cloud-init logs (if using cloud-init)
sudo tail -f /var/log/cloud-init-output.log
```

## 🚀 Production Considerations

When moving from this development setup to production:

### 1. Vault Configuration

```hcl
# /etc/vault/vault.hcl
storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = 1
}

api_addr = "https://vault.yourdomain.com"
cluster_addr = "https://vault.yourdomain.com:8201"
ui = true
```

### 2. High Availability Setup

- Multiple Vault nodes with Consul or integrated storage
- Load balancer (ALB/NLB) instead of single NGINX
- Auto-unsealing with AWS KMS
- Backup and disaster recovery procedures

### 3. Authentication and Authorization

```bash
# Enable AppRole authentication
vault auth enable approle

# Create policies instead of using root token
vault policy write app-policy - <<EOF
path "secret/data/app/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF
```

### 4. Monitoring and Alerting

- CloudWatch integration
- Prometheus metrics
- Grafana dashboards
- PagerDuty alerts for certificate expiry

## 📋 Summary Checklist

After completing this guide, you should have:

- ✅ HashiCorp Vault running in development mode
- ✅ NGINX reverse proxy with HTTPS termination
- ✅ Valid Let's Encrypt SSL certificate
- ✅ Automatic certificate renewal configured
- ✅ Security headers configured
- ✅ HTTP to HTTPS redirect
- ✅ Systemd services properly configured
- ✅ Basic monitoring and logging setup

## 📚 Additional Resources

- [HashiCorp Vault Documentation](https://developer.hashicorp.com/vault/docs)
- [NGINX Reverse Proxy Guide](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot User Guide](https://certbot.eff.org/docs/using.html)
- [Ubuntu Server Guide](https://ubuntu.com/server/docs)

## 🎯 Learning Outcomes

By following this guide, you've learned:

1. **System Administration**: Managing users, permissions, and systemd services
2. **Network Configuration**: Understanding reverse proxies and SSL termination
3. **Security**: Implementing HTTPS, security headers, and certificate management
4. **Troubleshooting**: Diagnosing and fixing common issues
5. **Automation**: Setting up automatic certificate renewal

This knowledge prepares you for more advanced topics like production Vault deployments, high availability configurations, and enterprise security implementations.