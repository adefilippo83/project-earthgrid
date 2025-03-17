#!/usr/bin/env python3
"""
Script to validate PR changes for both tinc VPN and Tahoe-LAFS configuration.
"""
import os
import sys
import yaml
import re
import ipaddress

def main():
    errors = []
    
    # Validate Tinc VPN Configuration
    errors.extend(validate_tinc_configuration())
    
    # Validate Tahoe-LAFS Configuration (if it exists)
    tahoe_inventory_path = 'tahoe/inventory/tahoe-nodes.yml'
    if os.path.exists(tahoe_inventory_path):
        errors.extend(validate_tahoe_configuration(tahoe_inventory_path))
    
    print_results(errors)

def validate_tinc_configuration():
    """Validate the Tinc VPN configuration"""
    errors = []
    
    # Check if tinc/inventory/nodes.yml exists
    if not os.path.exists('tinc/inventory/nodes.yml'):
        errors.append("tinc/inventory/nodes.yml file not found")
        return errors
    
    # Load node inventory
    try:
        with open('tinc/inventory/nodes.yml', 'r') as f:
            inventory = yaml.safe_load(f)
    except Exception as e:
        errors.append(f"Failed to parse tinc/inventory/nodes.yml: {str(e)}")
        return errors
    
    # Validate inventory structure
    if not isinstance(inventory, dict) or 'nodes' not in inventory:
        errors.append("Invalid inventory structure: 'nodes' list not found")
        return errors
    
    # Build a map of node names and IPs
    node_map = {}
    ip_map = {}
    for node in inventory['nodes']:
        if 'name' not in node or 'vpn_ip' not in node:
            errors.append(f"Node missing required fields: {node}")
            continue
            
        node_map[node['name']] = node['vpn_ip']
        
        # Check for IP conflicts
        if node['vpn_ip'] in ip_map:
            errors.append(f"IP conflict: {node['vpn_ip']} assigned to both {node['name']} and {ip_map[node['vpn_ip']]}")
        else:
            ip_map[node['vpn_ip']] = node['name']
    
    # Validate host files
    host_files = os.listdir('tinc/hosts') if os.path.exists('tinc/hosts') else []
    for filename in host_files:
        node_name = filename
        
        # Check if node exists in inventory
        if node_name not in node_map:
            errors.append(f"Host file {node_name} exists but not defined in tinc/inventory/nodes.yml")
            continue
            
        # Read host file
        try:
            with open(f'tinc/hosts/{node_name}', 'r') as f:
                host_content = f.read()
                
            # Check for public key
            if "BEGIN RSA PUBLIC KEY" not in host_content:
                errors.append(f"Host file {node_name} does not contain a public key")
                
            # Check for correct subnet
            expected_subnet = f"Subnet = {node_map[node_name]}/32"
            if expected_subnet not in host_content:
                errors.append(f"Host file {node_name} does not contain correct subnet: {expected_subnet}")
                
        except Exception as e:
            errors.append(f"Failed to parse host file {node_name}: {str(e)}")
    
    # Check for missing host files
    for node_name in node_map:
        if node_name not in host_files:
            errors.append(f"Node {node_name} defined in inventory but has no host file")
    
    return errors

def validate_tahoe_configuration(tahoe_inventory_path):
    """Validate the Tahoe-LAFS configuration"""
    errors = []
    
    # Load Tahoe node inventory
    try:
        with open(tahoe_inventory_path, 'r') as f:
            tahoe_inventory = yaml.safe_load(f)
    except Exception as e:
        errors.append(f"Failed to parse {tahoe_inventory_path}: {str(e)}")
        return errors
    
    # Validate Tahoe inventory structure
    if not isinstance(tahoe_inventory, dict) or 'nodes' not in tahoe_inventory:
        errors.append(f"Invalid Tahoe inventory structure: 'nodes' list not found in {tahoe_inventory_path}")
        return errors
    
    # Load Tinc inventory to cross-reference
    try:
        with open('tinc/inventory/nodes.yml', 'r') as f:
            tinc_inventory = yaml.safe_load(f)
            tinc_nodes = {node['name']: node for node in tinc_inventory['nodes']}
    except Exception as e:
        errors.append(f"Failed to parse tinc/inventory/nodes.yml for cross-reference: {str(e)}")
        tinc_nodes = {}
    
    # Check for at least one introducer
    has_introducer = False
    
    # Valid Tahoe roles
    valid_roles = {'introducer', 'storage', 'client', 'web'}
    
    # Validate each Tahoe node
    for node in tahoe_inventory['nodes']:
        # Check for required fields
        if 'name' not in node:
            errors.append(f"Tahoe node missing required 'name' field: {node}")
            continue
        
        node_name = node['name']
        
        # Check that node exists in Tinc inventory
        if node_name not in tinc_nodes:
            errors.append(f"Tahoe node '{node_name}' not found in Tinc VPN inventory")
        
        # Check Tahoe roles
        if 'tahoe_roles' not in node:
            errors.append(f"Tahoe node '{node_name}' missing required 'tahoe_roles' field")
            continue
        
        # Validate roles
        if not isinstance(node['tahoe_roles'], list):
            errors.append(f"Tahoe node '{node_name}' has 'tahoe_roles' that is not a list")
            continue
        
        # Check for invalid roles
        invalid_roles = [role for role in node['tahoe_roles'] if role not in valid_roles]
        if invalid_roles:
            errors.append(f"Tahoe node '{node_name}' has invalid roles: {', '.join(invalid_roles)}")
        
        # Check if this is an introducer
        if 'introducer' in node['tahoe_roles']:
            has_introducer = True
        
        # If it's a storage node, check for storage size
        if 'storage' in node['tahoe_roles'] and 'tahoe_storage_size' not in node:
            errors.append(f"Storage node '{node_name}' missing required 'tahoe_storage_size' field")
        
        # If it has a web role, check for web port
        if 'web' in node['tahoe_roles'] and 'tahoe_web_port' not in node:
            errors.append(f"Web gateway node '{node_name}' missing required 'tahoe_web_port' field")
    
    # Verify we have at least one introducer in the grid
    if not has_introducer:
        errors.append("No introducer node defined in Tahoe configuration")
    
    return errors

def print_results(errors):
    if errors:
        print("❌ Validation failed with the following errors:")
        for error in errors:
            print(f"  - {error}")
        sys.exit(1)
    else:
        print("✅ Validation passed successfully")
        sys.exit(0)

if __name__ == "__main__":
    main()
