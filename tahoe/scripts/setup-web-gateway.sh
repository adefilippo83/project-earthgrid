#!/bin/bash
# This script sets up a Tahoe-LAFS web gateway

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

# Ensure client node is set up first
if [ ! -d "$TAHOE_DIR/client" ]; then
    echo "Error: Client node is not set up. Please run setup-client-node.sh first."
    exit 1
fi

# Get web port from inventory
WEB_PORT=$($PYTHON_CMD -c "
import yaml, sys
try:
   with open('$REPO_DIR/tahoe/inventory/tahoe-nodes.yml', 'r') as f:
       config = yaml.safe_load(f)
   for node in config['nodes']:
       if node['name'] == '$NODE_NAME' and 'tahoe_web_port' in node:
           print(node['tahoe_web_port'])
           break
   else:
       print('3456')  # Default if not specified
except Exception as e:
   print('3456')  # Default if error
")

# Create web gateway directory (using the same as client)
WEB_DIR="$TAHOE_DIR/client"

# Customize configuration with web template
cp "$REPO_DIR/tahoe/config/web.cfg.template" "$WEB_DIR/tahoe.cfg"
sed -i "s|%INTRODUCER_FURL%|$(grep "introducer.furl" "$WEB_DIR/tahoe.cfg" | cut -d= -f2 | tr -d ' ')|g" "$WEB_DIR/tahoe.cfg"
sed -i "s/%VPN_IP%/$VPN_IP/g" "$WEB_DIR/tahoe.cfg"
sed -i "s/%NODE_NAME%/$NODE_NAME/g" "$WEB_DIR/tahoe.cfg"
sed -i "s/%WEB_PORT%/$WEB_PORT/g" "$WEB_DIR/tahoe.cfg"

# Ensure proper permissions
chown -R tahoe:tahoe "$WEB_DIR"

# Set up systemd service for web gateway
cp "$REPO_DIR/tahoe/systemd/tahoe-web.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable tahoe-web
systemctl start tahoe-web

# Configure firewall if ufw is installed
if command -v ufw >/dev/null 2>&1; then
    # Only allow access from VPN subnet
    ufw allow from 172.16.0.0/16 to any port $WEB_PORT
    echo "Firewall configured to allow web access only from VPN subnet"
fi

echo "Web gateway setup complete!"
echo "You can access the web interface at: http://$VPN_IP:$WEB_PORT/"
echo "NOTE: This interface is only accessible from within the VPN network for security."
