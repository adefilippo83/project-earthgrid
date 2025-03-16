#!/bin/bash
# This script generates new keys for a node and adds them to the repository

set -e

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root. Try 'sudo $0'"
   exit 1
fi

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
TINC_CONFIG_DIR="$(dirname "$SCRIPT_DIR")"
REPO_DIR="$(dirname "$TINC_CONFIG_DIR")"
NETWORK_NAME="pi-net"

# Get node name from argument
if [ -z "$1" ]; then
   echo "Usage: $0 <node_name>"
   exit 1
fi

NODE_NAME=$1
TINC_DIR="/etc/tinc/$NETWORK_NAME"

# Check if Tinc is installed
if ! command -v tincd &>/dev/null; then
   echo "Tinc is not installed. Please install it first."
   exit 1
fi

# Create directories if they don't exist
mkdir -p "$TINC_DIR/hosts"

# Generate subnet configuration for the host file
if python3 -c "
import yaml, sys
try:
   with open('$TINC_CONFIG_DIR/inventory/nodes.yml', 'r') as f:
       config = yaml.safe_load(f)
   for node in config['nodes']:
       if node['name'] == '$NODE_NAME':
           print(f\"Subnet = {node['vpn_ip']}/32\")
           if 'public_ip' in node and node.get('is_publicly_accessible', False):
               print(f\"Address = {node['public_ip']}\")
           print(\"Port = 655\")
           break
   else:
       print(f'Node {NODE_NAME} not found in inventory!')
       sys.exit(1)
except Exception as e:
   print(f'Error: {e}', file=sys.stderr)
   sys.exit(1)
" > "$TINC_DIR/hosts/$NODE_NAME.temp"; then
   # Move the temporary file to the host file
   mv "$TINC_DIR/hosts/$NODE_NAME.temp" "$TINC_DIR/hosts/$NODE_NAME"
else
   echo "Failed to generate host file. Check inventory/nodes.yml"
   exit 1
fi

# Generate the keys
echo "Generating RSA keys for $NODE_NAME..."
tincd -n "$NETWORK_NAME" -K4096

# Copy the public key to the repo
if [ -f "$TINC_DIR/hosts/$NODE_NAME" ]; then
   cp "$TINC_DIR/hosts/$NODE_NAME" "$TINC_CONFIG_DIR/hosts/"
   
   echo "Keys generated successfully!"
   echo "Public key saved to $TINC_CONFIG_DIR/hosts/$NODE_NAME"
   echo ""
   echo "To submit this key to the repository via a pull request:"
   echo "1. Create a new branch:"
   echo "   cd $REPO_DIR && git checkout -b add-node-$NODE_NAME"
   echo ""
   echo "2. Add and commit your key:"
   echo "   git add tinc/hosts/$NODE_NAME && git commit -m \"Add public key for $NODE_NAME\""
   echo ""
   echo "3. Push to your fork and create a pull request:"
   echo "   git push origin add-node-$NODE_NAME"
   echo ""
   echo "4. Visit your GitHub repository to create the pull request"
else
   echo "Error: Failed to generate keys!"
   exit 1
fi
