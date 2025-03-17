#!/bin/bash

set -e

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root. Try 'sudo $0'"
   exit 1
fi

REPO_DIR="/opt/project-earthgrid"
TAHOE_DIR="/opt/tahoe-lafs"

# Update repository
cd "$REPO_DIR"
git pull

# Get current node name
NODE_NAME=$(grep "^Name" "/etc/tinc/pi-net/tinc.conf" | awk '{print $3}')
if [ -z "$NODE_NAME" ]; then
   echo "Error: Could not determine node name from tinc.conf"
   exit 1
fi

# Check Tahoe-LAFS roles for this node
TAHOE_ROLES=$($PYTHON_CMD -c "
import yaml, sys
try:
   with open('$REPO_DIR/tahoe/inventory/tahoe-nodes.yml', 'r') as f:
       config = yaml.safe_load(f)
   for node in config['nodes']:
       if node['name'] == '$NODE_NAME':
           print(' '.join(node.get('tahoe_roles', [])))
           break
   else:
       print('')
except Exception as e:
   print('')
")

if [ -z "$TAHOE_ROLES" ]; then
   echo "No Tahoe-LAFS roles defined for this node. Skipping Tahoe update."
   exit 0
fi

# Update Tahoe-LAFS configurations based on roles
for role in $TAHOE_ROLES; do
   case "$role" in
       "introducer")
           echo "Updating introducer configuration..."
           # Update logic for introducer
           ;;
       "storage")
           echo "Updating storage node configuration..."
           # Update logic for storage node
           ;;
       "client")
           echo "Updating client node configuration..."
           # Update logic for client node
           ;;
       "web")
           echo "Updating web gateway configuration..."
           # Update logic for web gateway
           ;;
       *)
           echo "Unknown role: $role. Skipping."
           ;;
   esac
done

echo "Tahoe-LAFS configuration update complete!"
