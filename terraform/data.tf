# Get current AWS region
data "aws_region" "current" {}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Ubuntu 22.04 LTS "Jammy" AMI lookup (most reliable)
data "aws_ami" "ubuntu_22_jammy" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Alternative Ubuntu 22.04 lookup with different naming pattern
data "aws_ami" "ubuntu_22_alt" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Ubuntu 20.04 LTS "Focal" AMI lookup (backup)
data "aws_ami" "ubuntu_20_focal" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Local to determine which AMI to use
locals {
  # Priority: Try 22.04 Jammy first (most reliable), then alternatives, then regional fallback
  selected_ami = try(
    data.aws_ami.ubuntu_22_jammy.id,
    data.aws_ami.ubuntu_22_alt.id,
    data.aws_ami.ubuntu_20_focal.id,
    null
  )

  # Comprehensive regional AMI fallback map (Ubuntu 22.04 LTS)
  # These are known working AMIs as of September 2024
  regional_amis = {
    us-east-1      = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS
    us-east-2      = "ami-0fa49cc9dc8d62c84" # Ubuntu 22.04 LTS
    us-west-1      = "ami-0d5b6881eb60b2b6b" # Ubuntu 22.04 LTS
    us-west-2      = "ami-04dd23e62ed049936" # Ubuntu 22.04 LTS
    ca-central-1   = "ami-0a7154091c5c6623e" # Ubuntu 22.04 LTS
    ca-west-1      = "ami-0c28d70685a896c54" # Ubuntu 22.04 LTS
    eu-west-1      = "ami-0c1bc246476a5572b" # Ubuntu 22.04 LTS
    eu-west-2      = "ami-0b2ed2ec3696a5fd6" # Ubuntu 22.04 LTS
    eu-west-3      = "ami-00ac2849e4d8481c2" # Ubuntu 22.04 LTS
    eu-central-1   = "ami-065ab11fbd2f69400" # Ubuntu 22.04 LTS
    eu-north-1     = "ami-08eb150f611ca277f" # Ubuntu 22.04 LTS
    eu-south-1     = "ami-0e067cc8a2b58de59" # Ubuntu 22.04 LTS
    ap-southeast-1 = "ami-0b72821e2f177b45f" # Ubuntu 22.04 LTS
    ap-southeast-2 = "ami-0b1e534a4ff9019e0" # Ubuntu 22.04 LTS
    ap-southeast-3 = "ami-060e277c0d4cce553" # Ubuntu 22.04 LTS
    ap-northeast-1 = "ami-09a81b370b76de6a2" # Ubuntu 22.04 LTS
    ap-northeast-2 = "ami-040c33c6a51fd5d96" # Ubuntu 22.04 LTS
    ap-northeast-3 = "ami-0f9816f78187c68fb" # Ubuntu 22.04 LTS
    ap-south-1     = "ami-0dee22c13ea7a9a67" # Ubuntu 22.04 LTS
    ap-east-1      = "ami-0e86e20dae90224ba" # Ubuntu 22.04 LTS
    sa-east-1      = "ami-0fb487b797a4e0dd1" # Ubuntu 22.04 LTS
    me-south-1     = "ami-0a628e1e89aaedf80" # Ubuntu 22.04 LTS
    af-south-1     = "ami-0b45ae66668865cd6" # Ubuntu 22.04 LTS
  }

  # Final AMI selection with regional fallback
  final_ami = coalesce(
    var.ami_id != "" ? var.ami_id : null,
    local.selected_ami,
    local.regional_amis[data.aws_region.current.name],
    "ami-04dd23e62ed049936" # Default to us-west-2 Ubuntu 22.04 LTS
  )

  # Determine which Ubuntu version is being used for output
  ubuntu_version = var.ami_id != "" ? "Custom AMI" : try(
    data.aws_ami.ubuntu_22_jammy.id != null ? "22.04 LTS (Jammy)" : "",
    data.aws_ami.ubuntu_22_alt.id != null ? "22.04 LTS" : "",
    data.aws_ami.ubuntu_20_focal.id != null ? "20.04 LTS (Focal)" : "",
    "22.04 LTS (regional fallback)"
  )

  # AMI description for debugging
  ami_description = var.ami_id != "" ? "User-specified AMI" : try(
    data.aws_ami.ubuntu_22_jammy.description,
    data.aws_ami.ubuntu_22_alt.description,
    data.aws_ami.ubuntu_20_focal.description,
    "Regional fallback AMI - Ubuntu 22.04 LTS"
  )

  # AMI source for debugging
  ami_source = var.ami_id != "" ? "manual override" : try(
    data.aws_ami.ubuntu_22_jammy.id != null ? "ubuntu_22_jammy data source" : "",
    data.aws_ami.ubuntu_22_alt.id != null ? "ubuntu_22_alt data source" : "",
    data.aws_ami.ubuntu_20_focal.id != null ? "ubuntu_20_focal data source" : "",
    "regional fallback mapping"
  )
}