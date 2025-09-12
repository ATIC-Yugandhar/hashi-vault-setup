#!/usr/bin/env python3
"""
Dynamic Inventory Script for Ansible + Terraform Integration
Reads Terraform state to generate Ansible inventory dynamically
"""

import json
import subprocess
import sys
import os

def get_terraform_output():
    """Get Terraform output values"""
    try:
        # Change to parent directory where terraform files are
        terraform_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        
        result = subprocess.run(
            ['terraform', 'output', '-json'],
            cwd=terraform_dir,
            capture_output=True,
            text=True,
            check=True
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error running terraform output: {e}", file=sys.stderr)
        return {}
    except json.JSONDecodeError as e:
        print(f"Error parsing terraform output: {e}", file=sys.stderr)
        return {}

def generate_inventory():
    """Generate Ansible inventory from Terraform output"""
    terraform_output = get_terraform_output()
    
    # Extract values from terraform output
    try:
        ec2_ip = terraform_output.get('ec2_public_ip', {}).get('value', '')
        vault_domain = terraform_output.get('vault_domain', {}).get('value', 'vault.example.com')
        vault_version = '1.15.6'  # Default version
        vault_token = 'vault-dev-root-token'
        
        if not ec2_ip:
            print("Error: Could not get EC2 IP from terraform output", file=sys.stderr)
            return {"_meta": {"hostvars": {}}}
            
    except KeyError as e:
        print(f"Error: Missing key in terraform output: {e}", file=sys.stderr)
        return {"_meta": {"hostvars": {}}}
    
    # Build inventory structure
    inventory = {
        "vault_servers": {
            "hosts": ["vault_server"],
            "vars": {
                "vault_version": vault_version,
                "vault_domain": vault_domain,
                "vault_root_token": vault_token
            }
        },
        "_meta": {
            "hostvars": {
                "vault_server": {
                    "ansible_host": ec2_ip,
                    "ansible_user": "ubuntu",
                    "ansible_ssh_private_key_file": "../vault-ssh-key.pem",
                    "ansible_ssh_common_args": "-o StrictHostKeyChecking=no"
                }
            }
        }
    }
    
    return inventory

def main():
    """Main function to handle inventory requests"""
    if len(sys.argv) == 2 and sys.argv[1] == '--list':
        # Return full inventory
        inventory = generate_inventory()
        print(json.dumps(inventory, indent=2))
    elif len(sys.argv) == 3 and sys.argv[1] == '--host':
        # Return host-specific variables (already included in _meta)
        print(json.dumps({}))
    else:
        print("Usage: dynamic_inventory.py --list | --host <hostname>", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()