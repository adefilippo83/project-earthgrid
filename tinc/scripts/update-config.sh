#!/bin/bash
# This script updates the configuration for an existing node from the repository

set -e

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root. Try 'sudo $0'"
   exit 1
fi

REPO_DIR="/opt/project-earthgrid"
TINC_CONFIG_DIR="$REPO_DIR/tinc"
NETWORK_NAME="pi-net"
TINC_DIR="/etc/tinc/$NETWORK_NAME"

# Update repository
cd "$REPO_DIR"
git pull

# Get the current node name
NODE_NAME=$(grep "^Name" "$TINC_DIR/tinc.conf" | awk '{print $3}')
if [ -z "$NODE_NAME" ]; then
   echo "Error: Could not determine node name from tinc.conf"
   exit 1
fi

echo "Updating configuration for node $NODE_NAME"

# Copy all host files from repo
echo "Updating host files from repository..."
for host_file in "$TINC_CONFIG_DIR/hosts/"*; do
   if [ -f "$host_file" ]; then
       # Don't overwrite our own host file which contains private key
       if [ "$(basename "$host_file")" != "$NODE_NAME" ]; then
           cp "$host_file" "$TINC_DIR/hosts/"
       fi
   fi
done

# Determine Python command to use
if command -v python3 >/dev/null 2>&1; then
   PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
   PYTHON_CMD="python"
else
   echo "Python is not installed. Cannot parse YAML configuration."
   exit 1
fi

# Check for changes in node configuration
echo "Checking for node configuration changes..."
if $PYTHON_CMD -c "
import yaml, os, sys
try:
   with open('$TINC_CONFIG_DIR/inventory/nodes.yml', 'r') as f:
       config = yaml.safe_load(f)
   found = False
   for node in config['nodes']:
       if node['name'] == '$NODE_NAME':
           found = True
           vpn_ip = node['vpn_ip']
           # Check if VPN IP has changed
           with open('$TINC_DIR/tinc-up', 'r') as f:
               current_ip = None
               for line in f:
                   if 'ip addr add' in line:
                       current_ip = line.split()[3].split('/')[0]
                       break
           
           if current_ip != vpn_ip:
               print(f'VPN IP has changed from {current_ip} to {vpn_ip}')
               sys.exit(2)  # IP has changed
           
           # Check if hostname has changed in host file
           if 'hostname' in node:
               hostname_changed = False
               current_hostname = None
               host_file_path = '$TINC_DIR/hosts/$NODE_NAME'
               
               if os.path.exists(host_file_path):
                   with open(host_file_path, 'r') as f:
                       for line in f:
                           if 'Address = ' in line:
                               current_hostname = line.strip().split('Address = ')[1]
                               break
                   
                   if current_hostname and current_hostname != node['hostname']:
                       print(f'Hostname has changed from {current_hostname} to {node[\"hostname\"]}')
                       sys.exit(4)  # Hostname has changed
               else:
                   sys.exit(5)  # Host file doesn't exist yet
           
           break
   
   if not found:
       print(f'Node {NODE_NAME} not found in inventory!')
       sys.exit(1)
   
   # Check if connect configuration has changed - ONLY for publicly accessible nodes
   current_connects = set()
   with open('$TINC_DIR/tinc.conf', 'r') as f:
       for line in f:
           if line.startswith('ConnectTo'):
               current_connects.add(line.strip())
   
   new_connects = set()
   for node in config['nodes']:
       if node['name'] != '$NODE_NAME' and node.get('is_publicly_accessible', False):
           new_connects.add(f'ConnectTo = {node[\"name\"]}')
   
   if current_connects != new_connects:
       print('ConnectTo configuration has changed')
       sys.exit(3)  # Connect configuration has changed
   
   sys.exit(0)  # No changes needed
except Exception as e:
   print(f'Error: {e}', file=sys.stderr)
   sys.exit(1)
"; then
   echo "No configuration changes needed."
else
   exit_code=$?
   echo "Configuration changes detected (code $exit_code). Updating..."
   
   # Re-run the setup script to apply changes
   bash "$TINC_CONFIG_DIR/scripts/setup-node.sh" "$NODE_NAME"
   
   # Restart tinc service
   systemctl restart tinc@$NETWORK_NAME
   echo "Configuration updated and service restarted."
fi

# Check if this node has Tahoe-LAFS roles and update those configurations
if [ -f "$REPO_DIR/tahoe/inventory/tahoe-nodes.yml" ]; then
    bash "$REPO_DIR/tahoe/scripts/update-tahoe-config.sh"
fi

echo "Update complete!"
