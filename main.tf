# =============================================================================
# TERRAFORM CONFIGURATION
# =============================================================================
# This file contains the core Terraform configuration for a HashiCorp Vault
# development environment deployment on AWS.
#
# Purpose: Deploy a single-node Vault server with TLS certificates and
#          supporting infrastructure for development/testing purposes.
#
# Security Note: This configuration is designed for development environments
#                and should NOT be used in production without significant
#                security hardening.
# =============================================================================

terraform {
  # Minimum Terraform version required
  required_version = ">= 1.0"

  # Backend configuration for remote state storage
  # Same configuration used for both local development and GitHub Actions
  backend "s3" {
    bucket  = "yreddy-tf-state"
    key     = "vault-dev/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    # dynamodb_table = "terraform-state-lock"  # Commented out until table is created
  }

  # Required provider versions and sources
  required_providers {
    # AWS provider for cloud infrastructure
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # TLS provider for certificate generation
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    # Local provider for file operations
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# =============================================================================
# PROVIDER CONFIGURATION
# =============================================================================

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  # Default tags applied to all resources
  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "vault-dev"
    }
  }
}

# =============================================================================
# TLS CERTIFICATE GENERATION
# =============================================================================
# Note: In production, use proper CA-signed certificates instead of self-signed

# Generate RSA private key for Vault TLS certificate
# Security: 2048-bit RSA key is minimum recommended for TLS
resource "tls_private_key" "vault_ca" {
  algorithm = "RSA"
  rsa_bits  = 2048

  # Lifecycle rule to prevent accidental key regeneration
  lifecycle {
    create_before_destroy = true
  }
}

# Generate self-signed TLS certificate for Vault HTTPS endpoint
# Security Warning: Self-signed certificates should not be used in production
resource "tls_self_signed_cert" "vault_cert" {
  private_key_pem = tls_private_key.vault_ca.private_key_pem

  # Certificate subject information
  subject {
    common_name  = var.vault_domain
    organization = "Vault Dev Instance"
  }

  # DNS names this certificate is valid for
  dns_names = [
    var.vault_domain,
    "localhost" # For local testing
  ]

  # IP addresses this certificate is valid for
  ip_addresses = [
    "127.0.0.1" # Localhost/loopback
  ]

  # Certificate validity: 1 year (8760 hours)
  # Security: Keep certificate lifetimes reasonable for dev environments
  validity_period_hours = 8760

  # Certificate key usage - standard server authentication uses
  allowed_uses = [
    "key_encipherment",  # Encrypt symmetric keys
    "digital_signature", # Digital signatures
    "server_auth",       # TLS server authentication
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# SECURE PARAMETER STORAGE
# =============================================================================
# Store TLS certificate and private key in AWS Systems Manager Parameter Store
# Security: Using SecureString type for encryption at rest with KMS

# Store the TLS certificate (public key)
# Note: Certificate can be stored as SecureString for consistency, though it's not secret
resource "aws_ssm_parameter" "vault_cert" {
  name        = "/vault/tls/cert"
  type        = "SecureString"
  value       = tls_self_signed_cert.vault_cert.cert_pem
  description = "Vault TLS certificate for HTTPS endpoint"

  tags = var.tags
}

# Store the TLS private key
# Security: Private key MUST be stored as SecureString and encrypted
resource "aws_ssm_parameter" "vault_key" {
  name        = "/vault/tls/key"
  type        = "SecureString"
  value       = tls_private_key.vault_ca.private_key_pem
  description = "Vault TLS private key - HIGHLY SENSITIVE"

  tags = var.tags
}

# =============================================================================
# SSH KEY PAIR GENERATION
# =============================================================================
# Generate SSH key pair for secure EC2 instance access
# Security: Using 4096-bit RSA for enhanced security

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096 # Enhanced security: 4096-bit key

  lifecycle {
    create_before_destroy = true
  }
}

# Save SSH private key to local file with restricted permissions
# Security: File permissions set to 0600 (owner read/write only)
# Note: For highly sensitive content, consider using local_sensitive_file resource
resource "local_file" "ssh_private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/vault-ssh-key.pem"
  file_permission = "0600" # Owner read/write only for security
}

# Save SSH public key to local file
# Security: Public key can have standard read permissions
resource "local_file" "ssh_public_key" {
  content         = tls_private_key.ssh_key.public_key_openssh
  filename        = "${path.module}/vault-ssh-key.pub"
  file_permission = "0644" # Standard read permissions for public key
}

# Optionally store SSH keys in Parameter Store for centralized management
# Security: Private key stored as SecureString, public key as standard String

# Store SSH private key in Parameter Store (optional)
# Security: HIGHLY SENSITIVE - only store if centralized key management is needed
resource "aws_ssm_parameter" "ssh_private_key" {
  count       = var.store_ssh_key_in_ssm ? 1 : 0
  name        = "/vault/${var.environment}/ssh-private-key"
  type        = "SecureString"
  value       = tls_private_key.ssh_key.private_key_pem
  description = "SSH private key for Vault EC2 instance - HIGHLY SENSITIVE"

  tags = var.tags
}

# Store SSH public key in Parameter Store (optional)
resource "aws_ssm_parameter" "ssh_public_key" {
  count       = var.store_ssh_key_in_ssm ? 1 : 0
  name        = "/vault/${var.environment}/ssh-public-key"
  type        = "String" # Public key doesn't need encryption
  value       = tls_private_key.ssh_key.public_key_openssh
  description = "SSH public key for Vault EC2 instance"

  tags = var.tags
}