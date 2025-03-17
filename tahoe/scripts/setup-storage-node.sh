#!/bin/bash

set -e

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root. Try 'sudo $0'"
   exit 1
fi

REPO_DIR="/opt/project-earthgrid"
TAHOE_DIR="/opt/tahoe-lafs"
NODE_NAME="$1"
VPN_IP=$(grep "Subnet" /etc/tinc/pi-net/hosts/$NODE_NAME | awk '{print $3}' | cut -d'/' -f1)

# Get storage size from inventory
STORAGE_SIZE=$($PYTHON_CMD -c "
import yaml, sys
try:
   with open('$REPO_DIR/tahoe/inventory/tahoe-nodes.yml', 'r') as f:
       config = yaml.safe_load(f)
   for node in config['nodes']:
       if node['name'] == '$NODE_NAME':
           print(node.get('tahoe_storage_size', '50GB'))
           break
except Exception as e:
   print('50GB')  # Default if not specified
")

# Create directories
mkdir -p "$TAHOE_DIR/storage"

# Get introducer FURL
INTRODUCER_FURL=$(cat "$REPO_DIR/tahoe/config/introducer.furl")

# Generate storage node configuration
tahoe create-node "$TAHOE_DIR/storage"

# Customize configuration with template
cp "$REPO_DIR/tahoe/config/storage.cfg.template" "$TAHOE_DIR/storage/tahoe.cfg"
sed -i "s|%INTRODUCER_FURL%|$INTRODUCER_FURL|g" "$TAHOE_DIR/storage/tahoe.cfg"
sed -i "s/%VPN_IP%/$VPN_IP/g" "$TAHOE_DIR/storage/tahoe.cfg"
sed -i "s/%NODE_NAME%/$NODE_NAME/g" "$TAHOE_DIR/storage/tahoe.cfg"
sed -i "s/%STORAGE_SIZE%/$STORAGE_SIZE/g" "$TAHOE_DIR/storage/tahoe.cfg"

# Set up systemd service
cp "$REPO_DIR/tahoe/systemd/tahoe-storage.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable tahoe-storage
systemctl start tahoe-storage

echo "Storage node setup complete!"
