#!/bin/bash
set -e

echo "=== HashiCorp Vault Ansible Setup ==="

# Get current IP from Terraform
VAULT_IP=$(terraform output -raw ec2_public_ip)
VAULT_DOMAIN=$(terraform output -raw vault_domain)

if [ -z "$VAULT_IP" ]; then
    echo "❌ Error: Could not get EC2 IP from terraform output"
    exit 1
fi

echo "📍 Target IP: $VAULT_IP"
echo "🌐 Domain: $VAULT_DOMAIN"

# Dynamic inventory will be handled by the Python script

# Wait for SSH to be ready
echo "⏳ Waiting for SSH to be ready..."
for i in {1..30}; do
    if ssh -i ./vault-ssh-key.pem ubuntu@$VAULT_IP -o StrictHostKeyChecking=no -o ConnectTimeout=5 "echo 'SSH Ready'" 2>/dev/null; then
        echo "✅ SSH connection established"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ SSH connection timeout"
        exit 1
    fi
    echo "Attempt $i/30..."
    sleep 10
done

# Run Ansible playbook with dynamic inventory
echo "🚀 Running Ansible playbook..."
cd ansible
ansible-playbook -i dynamic_inventory.py vault-setup.yml -v

echo ""
echo "=== Setup Complete! ==="
echo "🌐 Vault URL: https://$VAULT_DOMAIN"
echo "🔑 Root Token: vault-dev-root-token"
echo "🔧 SSH: ssh -i ./vault-ssh-key.pem ubuntu@$VAULT_IP"