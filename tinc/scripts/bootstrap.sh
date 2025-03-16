#!/bin/bash
# This script bootstraps a new Raspberry Pi for the tinc VPN network

set -e

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root. Try 'sudo $0'"
   exit 1
fi

# Install required packages
apt-get update
apt-get install -y tinc git python3-yaml curl

# Get node name from argument or prompt
if [ -z "$1" ]; then
   read -p "Enter node name (e.g., node1): " NODE_NAME
else
   NODE_NAME=$1
fi

# Create tinc network directory
NETWORK_NAME="pi-net"
TINC_DIR="/etc/tinc/$NETWORK_NAME"
mkdir -p "$TINC_DIR/hosts"

REPO_DIR="/opt/project-earthgrid"
TINC_CONFIG_DIR="$REPO_DIR/tinc"
# Set up the first-time configuration
bash "$TINC_CONFIG_DIR/scripts/setup-node.sh" "$NODE_NAME"

# Enable and start tinc service
systemctl enable tinc@$NETWORK_NAME
systemctl start tinc@$NETWORK_NAME

echo "Bootstrap complete! Node $NODE_NAME is now part of the tinc VPN network."
echo "Check logs with: journalctl -u tinc@$NETWORK_NAME"
