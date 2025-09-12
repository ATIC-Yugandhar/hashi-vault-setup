# VPC
resource "aws_vpc" "vault_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "vault-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "vault_igw" {
  vpc_id = aws_vpc.vault_vpc.id

  tags = merge(var.tags, {
    Name = "vault-igw"
  })
}

# Public Subnet
resource "aws_subnet" "vault_public_subnet" {
  vpc_id                  = aws_vpc.vault_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "vault-public-subnet"
  })
}

# Route Table
resource "aws_route_table" "vault_public_rt" {
  vpc_id = aws_vpc.vault_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vault_igw.id
  }

  tags = merge(var.tags, {
    Name = "vault-public-rt"
  })
}

# Route Table Association
resource "aws_route_table_association" "vault_public_rta" {
  subnet_id      = aws_subnet.vault_public_subnet.id
  route_table_id = aws_route_table.vault_public_rt.id
}

# Security Group
resource "aws_security_group" "vault_sg" {
  name_prefix = "vault-sg"
  vpc_id      = aws_vpc.vault_vpc.id

  # SSH access from your IP only
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Vault HTTP access from your IP only (for dev mode)
  ingress {
    description = "Vault HTTP"
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # HTTPS access - TEMPORARILY OPEN FOR TESTING
  # TODO: Restrict back to specific IPs after JWT auth testing is complete
  ingress {
    description = "HTTPS - Open for testing"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to internet - FOR TESTING ONLY
  }

  # HTTP access for Let's Encrypt certificate validation
  # Security: Temporary access needed for certificate issuance/renewal
  ingress {
    description = "HTTP for Lets Encrypt"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Let's Encrypt needs to access from anywhere
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "vault-security-group"
  })
}