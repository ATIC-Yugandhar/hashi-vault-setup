# =============================================================================
# TERRAFORM VARIABLES
# =============================================================================
# Variable definitions for HashiCorp Vault development environment
# 
# Usage: Override defaults using terraform.tfvars file or -var flags
# Security: Never commit sensitive values to version control
# =============================================================================

# =============================================================================
# INFRASTRUCTURE CONFIGURATION
# =============================================================================

# Vault server URL
variable "vault_server_url" {
  description = "Vault server URL (e.g., https://vault.example.com:8200)"
  type        = string
}

# =============================================================================
# GITHUB CONFIGURATION
# =============================================================================

# GitHub organization name
variable "github_organization" {
  description = "GitHub organization name"
  type        = string
}

# GitHub repository name
variable "github_repository" {
  description = "GitHub repository name"
  type        = string
}

# AWS Region for resource deployment
# Security: Choose region based on compliance and latency requirements
variable "aws_region" {
  description = "AWS region to deploy resources in (affects latency and compliance)"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "AWS region must be in standard format (e.g., us-west-2, eu-west-1)."
  }
}

# =============================================================================
# DNS AND DOMAIN CONFIGURATION
# =============================================================================

# Fully qualified domain name for Vault access
# Security: Use dedicated subdomain for Vault (e.g., vault.company.com)
variable "vault_domain" {
  description = "Fully qualified domain name for Vault access (e.g., vault.example.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$", var.vault_domain))
    error_message = "Domain name must be a valid FQDN format."
  }
}

# Route53 hosted zone ID for DNS record creation
# Required: Must match the domain specified in vault_domain
variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS record creation (must own the domain)"
  type        = string

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.route53_zone_id))
    error_message = "Route53 zone ID must start with 'Z' followed by alphanumeric characters."
  }
}

# =============================================================================
# NETWORK SECURITY CONFIGURATION
# =============================================================================

# Client IP address for security group access control
# Security: CRITICAL - Restricts access to only specified IP address
variable "my_ip" {
  description = "Your public IP address in CIDR format (e.g., 203.0.113.42/32) - RESTRICTS ACCESS TO VAULT"
  type        = string

  validation {
    condition     = can(regex("^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/(?:3[0-2]|[12]?[0-9])$", var.my_ip))
    error_message = "IP must be in valid CIDR format (e.g., 203.0.113.42/32)."
  }
}

# =============================================================================
# COMPUTE CONFIGURATION
# =============================================================================

# EC2 AMI ID (optional - will auto-detect Ubuntu if not specified)
# Security: Use only trusted, regularly updated AMIs
variable "ami_id" {
  description = "EC2 AMI ID to use (optional - will auto-select latest Ubuntu 22.04 if empty)"
  type        = string
  default     = ""

  validation {
    condition     = var.ami_id == "" || can(regex("^ami-[a-f0-9]{8,17}$", var.ami_id))
    error_message = "AMI ID must be empty or in format ami-xxxxxxxx."
  }
}

# EC2 instance type for Vault server
# Security: t3.micro sufficient for development, use larger instances for production
variable "instance_type" {
  description = "EC2 instance type (t3.micro is sufficient for development)"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z][0-9][a-z]?\\.(nano|micro|small|medium|large|xlarge|[0-9]+xlarge)$", var.instance_type))
    error_message = "Instance type must be valid EC2 format (e.g., t3.micro, m5.large)."
  }
}

# =============================================================================
# VAULT CONFIGURATION
# =============================================================================

# HashiCorp Vault version to install
# Security: Use specific versions rather than 'latest' for reproducible builds
variable "vault_version" {
  description = "HashiCorp Vault version to install (use specific version for stability)"
  type        = string
  default     = "1.15.6" # Updated to match current working version

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+(-[a-z0-9]+)?$", var.vault_version))
    error_message = "Vault version must be in semantic version format (e.g., 1.15.2)."
  }
}

# =============================================================================
# ENVIRONMENT CONFIGURATION
# =============================================================================

# Environment designation (affects resource naming and tagging)
variable "environment" {
  description = "Environment name (affects resource naming and tagging)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod", "test"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, test."
  }
}

# =============================================================================
# KEY MANAGEMENT CONFIGURATION
# =============================================================================

# Whether to store SSH keys in AWS Parameter Store
# Security: Enables centralized key management but increases attack surface
variable "store_ssh_key_in_ssm" {
  description = "Store SSH keys in Parameter Store for centralized management (increases security complexity)"
  type        = bool
  default     = true
}

# =============================================================================
# RESOURCE TAGGING
# =============================================================================

# Default tags applied to all AWS resources
# Important: Consistent tagging enables cost tracking and resource management
variable "tags" {
  description = "Default tags applied to all AWS resources (important for cost tracking and governance)"
  type        = map(string)
  default = {
    Project     = "vault-dev"
    Environment = "dev"
    ManagedBy   = "terraform"
    Owner       = "development-team"
    Purpose     = "vault-development"
  }

  validation {
    condition     = contains(keys(var.tags), "Project") && contains(keys(var.tags), "Environment")
    error_message = "Tags must include 'Project' and 'Environment' keys."
  }
}