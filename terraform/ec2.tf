# IAM Role for EC2 to access SSM parameters
resource "aws_iam_role" "vault_ec2_role" {
  name = "vault-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for SSM parameter access
resource "aws_iam_policy" "vault_ssm_policy" {
  name        = "vault-ssm-policy"
  description = "Policy for Vault EC2 to access SSM parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = concat([
          aws_ssm_parameter.vault_cert.arn,
          aws_ssm_parameter.vault_key.arn
          ], var.store_ssh_key_in_ssm ? [
          aws_ssm_parameter.ssh_private_key[0].arn,
          aws_ssm_parameter.ssh_public_key[0].arn
        ] : [])
      }
    ]
  })

  tags = var.tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "vault_ssm_policy_attachment" {
  role       = aws_iam_role.vault_ec2_role.name
  policy_arn = aws_iam_policy.vault_ssm_policy.arn
}

# Instance profile
resource "aws_iam_instance_profile" "vault_instance_profile" {
  name = "vault-instance-profile"
  role = aws_iam_role.vault_ec2_role.name

  tags = var.tags
}

# Key pair for SSH access
resource "aws_key_pair" "vault_key" {
  key_name   = "vault-key"
  public_key = tls_private_key.ssh_key.public_key_openssh

  tags = var.tags
}

# EC2 Instance
resource "aws_instance" "vault" {
  ami                    = var.ami_id != "" ? var.ami_id : local.final_ami
  instance_type          = var.instance_type
  key_name               = aws_key_pair.vault_key.key_name
  vpc_security_group_ids = [aws_security_group.vault_sg.id]
  subnet_id              = aws_subnet.vault_public_subnet.id
  iam_instance_profile   = aws_iam_instance_profile.vault_instance_profile.name

  user_data = base64encode(templatefile("${path.module}/user-data.yml", {
    vault_version = var.vault_version
    vault_domain  = var.vault_domain
  }))

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = merge(var.tags, {
    Name = "vault-server"
  })

  lifecycle {
    create_before_destroy = true
  }
}