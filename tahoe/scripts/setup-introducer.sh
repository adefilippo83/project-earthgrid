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

# Create directories
mkdir -p "$TAHOE_DIR/introducer"

# Generate introducer configuration
tahoe create-introducer "$TAHOE_DIR/introducer"

# Customize configuration with template
cp "$REPO_DIR/tahoe/config/introducer.cfg.template" "$TAHOE_DIR/introducer/tahoe.cfg"
sed -i "s/%VPN_IP%/$VPN_IP/g" "$TAHOE_DIR/introducer/tahoe.cfg"
sed -i "s/%NODE_NAME%/$NODE_NAME/g" "$TAHOE_DIR/introducer/tahoe.cfg"

# Set up systemd service
cp "$REPO_DIR/tahoe/systemd/tahoe-introducer.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable tahoe-introducer
systemctl start tahoe-introducer

# Extract and publish introducer FURL
FURL=$(grep "introducer.furl" "$TAHOE_DIR/introducer/private/introducer.furl" | cut -d= -f2 | tr -d ' ')
echo "$FURL" > "$REPO_DIR/tahoe/config/introducer.furl"
echo "Introducer FURL: $FURL"

echo "Introducer node setup complete!"
