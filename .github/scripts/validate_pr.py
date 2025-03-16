#!/usr/bin/env python3
"""
Script to validate PR changes for tinc VPN configuration.
"""
import os
import sys
import yaml
import re
import ipaddress

def main():
   errors = []
   
   # Check if tinc/inventory/nodes.yml exists
   if not os.path.exists('tinc/inventory/nodes.yml'):
       errors.append("tinc/inventory/nodes.yml file not found")
       print_results(errors)
       return
   
   # Load node inventory
   try:
       with open('tinc/inventory/nodes.yml', 'r') as f:
           inventory = yaml.safe_load(f)
   except Exception as e:
       errors.append(f"Failed to parse tinc/inventory/nodes.yml: {str(e)}")
       print_results(errors)
       return
   
   # Validate inventory structure
   if not isinstance(inventory, dict) or 'nodes' not in inventory:
       errors.append("Invalid inventory structure: 'nodes' list not found")
       print_results(errors)
       return
   
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
   host_files = os.listdir('tinc/hosts')
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
   
   print_results(errors)

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
