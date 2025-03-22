#!/bin/bash
# This script sets up a Tahoe-LAFS client node

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

# Create tahoe user if it doesn't exist
if ! id -u tahoe &>/dev/null; then
    useradd --system --home-dir /opt/tahoe-lafs --shell /bin/bash tahoe
fi

# Create directories
mkdir -p "$TAHOE_DIR/client"
chown -R tahoe:tahoe "$TAHOE_DIR"

# Get introducer FURL
INTRODUCER_FURL=$(cat "$REPO_DIR/tahoe/config/introducer.furl")
if [ -z "$INTRODUCER_FURL" ]; then
    echo "Error: Introducer FURL not found. Please ensure the introducer is set up first."
    exit 1
fi

# Generate client node configuration
sudo -u tahoe tahoe create-client "$TAHOE_DIR/client"

# Customize configuration with template
cp "$REPO_DIR/tahoe/config/client.cfg.template" "$TAHOE_DIR/client/tahoe.cfg"
sed -i "s|%INTRODUCER_FURL%|$INTRODUCER_FURL|g" "$TAHOE_DIR/client/tahoe.cfg"
sed -i "s/%VPN_IP%/$VPN_IP/g" "$TAHOE_DIR/client/tahoe.cfg"
sed -i "s/%NODE_NAME%/$NODE_NAME/g" "$TAHOE_DIR/client/tahoe.cfg"

# Ensure proper permissions
chown -R tahoe:tahoe "$TAHOE_DIR/client"

# Set up systemd service
cp "$REPO_DIR/tahoe/systemd/tahoe-client.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable tahoe-client
systemctl start tahoe-client

# Create some convenient aliases
echo "Creating aliases for the Tahoe client..."
sudo -u tahoe tahoe create-alias grid

echo "Client node setup complete! You can now access the grid."
echo "Test with: sudo -u tahoe tahoe mkdir grid:test"
