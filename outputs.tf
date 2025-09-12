output "vault_url" {
  description = "Vault URL (HTTPS with Let's Encrypt)"
  value       = "https://${var.vault_domain}"
}

output "vault_domain" {
  description = "Vault domain name"
  value       = var.vault_domain
}

output "vault_root_token" {
  description = "Vault root token (dev mode)"
  value       = "vault-dev-root-token"
  sensitive   = true
}

output "ec2_public_ip" {
  description = "EC2 instance public IP"
  value       = aws_instance.vault.public_ip
}

output "ec2_ami_id" {
  description = "AMI ID used for the EC2 instance"
  value       = local.final_ami
}

output "ubuntu_version" {
  description = "Ubuntu version being used"
  value       = local.ubuntu_version
}

output "ami_description" {
  description = "Description of the AMI being used"
  value       = local.ami_description
}

output "ami_source" {
  description = "Source of the AMI selection"
  value       = local.ami_source
}

output "aws_region" {
  description = "AWS region used"
  value       = data.aws_region.current.name
}

output "ssh_private_key_file" {
  description = "Local path to SSH private key file"
  value       = local_file.ssh_private_key.filename
}

output "ssh_public_key_file" {
  description = "Local path to SSH public key file"
  value       = local_file.ssh_public_key.filename
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ${local_file.ssh_private_key.filename} ubuntu@${aws_instance.vault.public_ip}"
}

output "ssh_key_ssm_path" {
  description = "AWS Parameter Store path for SSH private key (if enabled)"
  value       = var.store_ssh_key_in_ssm ? aws_ssm_parameter.ssh_private_key[0].name : "Not stored in Parameter Store"
}

output "ssh_key_instructions" {
  description = "Instructions to access SSH key"
  value = var.store_ssh_key_in_ssm ? (
    <<-EOT
    SSH Key Locations:
    
    1. Local file (ready to use):
       ${local_file.ssh_private_key.filename}
       
    2. AWS Parameter Store:
       ${aws_ssm_parameter.ssh_private_key[0].name}
       
    SSH Commands:
    # Direct connection (key file already available)
    ssh -i ${local_file.ssh_private_key.filename} ubuntu@${aws_instance.vault.public_ip}
    
    # Or retrieve from Parameter Store
    aws ssm get-parameter --name "${aws_ssm_parameter.ssh_private_key[0].name}" --with-decryption --query 'Parameter.Value' --output text > temp-key.pem
    chmod 600 temp-key.pem
    ssh -i temp-key.pem ubuntu@${aws_instance.vault.public_ip}
    EOT
  ) : (
    <<-EOT
    SSH Key Locations:
    
    1. Local file (ready to use):
       ${local_file.ssh_private_key.filename}
       
    SSH Command:
    ssh -i ${local_file.ssh_private_key.filename} ubuntu@${aws_instance.vault.public_ip}
    EOT
  )
}

output "vault_login_instructions" {
  description = "Instructions to login to Vault"
  value = <<-EOT
    CLI Login:
    export VAULT_ADDR=https://${var.vault_domain}
    export VAULT_TOKEN=vault-dev-root-token
    vault status

    Web UI:
    Navigate to: https://${var.vault_domain}
    Token: vault-dev-root-token

    Security Features:
    - HTTPS with Let's Encrypt certificate
    - Automatic certificate renewal
    - Security headers configured
    - HTTP to HTTPS redirect

    Note: If certificate setup fails, access via: http://${var.vault_domain}:8200
  EOT
}