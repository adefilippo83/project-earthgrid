#!/bin/bash
# This script sets up a new node in the tinc VPN network

set -e

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root. Try 'sudo $0'"
   exit 1
fi

# Get node name from argument
if [ -z "$1" ]; then
   echo "Usage: $0 <node_name>"
   exit 1
fi

NODE_NAME=$1
NETWORK_NAME="pi-net"
TINC_DIR="/etc/tinc/$NETWORK_NAME"
REPO_DIR="/opt/project-earthgrid"
TINC_CONFIG_DIR="$REPO_DIR/tinc"

# Read configuration from nodes.yml
if command -v python3 >/dev/null 2>&1; then
   PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
   PYTHON_CMD="python"
else
   echo "Python is not installed. Cannot parse YAML configuration."
   exit 1
fi

# Parse node configuration from YAML - now with hostname
NODE_CONFIG=$($PYTHON_CMD -c "
import yaml, sys
try:
   with open('$TINC_CONFIG_DIR/inventory/nodes.yml', 'r') as f:
       config = yaml.safe_load(f)
   for node in config['nodes']:
       if node['name'] == '$NODE_NAME':
           print(f\"VPN_IP={node['vpn_ip']}\")
           if 'hostname' in node:
               print(f\"HOSTNAME={node['hostname']}\")
           elif 'public_ip' in node:
               print(f\"HOSTNAME={node['public_ip']}\")
           break
   else:
       sys.exit(1)
except Exception as e:
   print(f'Error: {e}', file=sys.stderr)
   sys.exit(1)
")

if [ $? -ne 0 ]; then
   echo "Error: Node $NODE_NAME not found in inventory/nodes.yml"
   exit 1
fi

# Extract VPN IP and hostname from configuration
eval "$NODE_CONFIG"
if [ -z "$VPN_IP" ]; then
   echo "Error: Could not determine VPN IP for node $NODE_NAME"
   exit 1
fi

echo "Setting up node $NODE_NAME with VPN IP $VPN_IP"
if [ -n "$HOSTNAME" ]; then
   echo "Using hostname: $HOSTNAME"
fi

# Create tinc.conf - first read the template
mkdir -p "$TINC_DIR/hosts"
TINC_CONF_TEMPLATE=$(cat "$TINC_CONFIG_DIR/config/tinc.conf.template")

# Generate connect lines ONLY for publicly accessible nodes
CONNECT_LINES=$($PYTHON_CMD -c "
import yaml
try:
   with open('$TINC_CONFIG_DIR/inventory/nodes.yml', 'r') as f:
       config = yaml.safe_load(f)
   for node in config['nodes']:
       if node['name'] != '$NODE_NAME' and node.get('is_publicly_accessible', False):
           print(f\"ConnectTo = {node['name']}\")
except Exception as e:
   print(f'Error: {e}', file=sys.stderr)
   sys.exit(1)
")

# Replace placeholders and write to tinc.conf
echo "${TINC_CONF_TEMPLATE}" | \
  sed "s/%NODE_NAME%/$NODE_NAME/g" | \
  sed "s/%CONNECT_TO_NODES%/$CONNECT_LINES/g" > "$TINC_DIR/tinc.conf"

# Create tinc-up and tinc-down scripts
cat "$TINC_CONFIG_DIR/config/tinc-up.template" | sed "s|%VPN_IP%|$VPN_IP|g" > "$TINC_DIR/tinc-up"
cp "$TINC_CONFIG_DIR/config/tinc-down.template" "$TINC_DIR/tinc-down"
chmod +x "$TINC_DIR/tinc-up" "$TINC_DIR/tinc-down"

# Copy existing host files from repo
for host_file in "$TINC_CONFIG_DIR/hosts/"*; do
   if [ -f "$host_file" ]; then
       # Don't copy this node's host file if it exists, as we'll create it properly below
       if [ "$(basename "$host_file")" != "$NODE_NAME" ]; then
           cp "$host_file" "$TINC_DIR/hosts/"
       fi
   fi
done

# Check if we already have keys for this node
if [ ! -f "$TINC_DIR/rsa_key.priv" ] || ! grep -q "BEGIN RSA PRIVATE KEY" "$TINC_DIR/rsa_key.priv"; then
   echo "Generating new keys for $NODE_NAME..."
   
   # Now create the host file manually with proper subnet and hostname
   HOST_FILE="$TINC_DIR/hosts/$NODE_NAME"
   echo "# Host file for $NODE_NAME" > "$HOST_FILE"
   echo "Subnet = $VPN_IP/32" >> "$HOST_FILE"
   
   # Add hostname if available
   if [ -n "$HOSTNAME" ]; then
      echo "Address = $HOSTNAME" >> "$HOST_FILE"
   fi
   
   echo "Port = 655" >> "$HOST_FILE"
   
   # Generate public key
   tincd -n "$NETWORK_NAME" -K < /dev/null
   
   # Copy to repo
   cp "$TINC_DIR/hosts/$NODE_NAME" "$TINC_CONFIG_DIR/hosts/"
   
   echo "New key generated. Please submit this via a pull request:"
   echo "1. Create a new branch:"
   echo "   cd $REPO_DIR && git checkout -b add-node-$NODE_NAME"
   echo ""
   echo "2. Add and commit your key:"
   echo "   git add tinc/hosts/$NODE_NAME tinc/inventory/nodes.yml && git commit -m \"Add public key for $NODE_NAME\""
   echo ""
   echo "3. Push and create a pull request:"
   echo "   git push origin add-node-$NODE_NAME"
   echo ""
   echo "4. Visit your GitHub repository to create the pull request"
   echo ""
   echo "Note: Your VPN will be fully operational only after this PR is approved and merged."
else
   echo "Using existing keys for $NODE_NAME"
   
   # Still need to ensure the host file has the correct subnet and hostname
   HOST_FILE="$TINC_DIR/hosts/$NODE_NAME"
   if [ -f "$HOST_FILE" ] && ! grep -q "Subnet = $VPN_IP/32" "$HOST_FILE"; then
      echo "Updating host file with subnet information..."
      cp "$HOST_FILE" "$HOST_FILE.bak"
      echo "# Host file for $NODE_NAME" > "$HOST_FILE"
      echo "Subnet = $VPN_IP/32" >> "$HOST_FILE"
      if [ -n "$HOSTNAME" ]; then
         echo "Address = $HOSTNAME" >> "$HOST_FILE"
      fi
      echo "Port = 655" >> "$HOST_FILE"
      grep -A 100 "BEGIN RSA PUBLIC KEY" "$HOST_FILE.bak" >> "$HOST_FILE"
      cp "$HOST_FILE" "$TINC_CONFIG_DIR/hosts/"
   fi
fi

# Verify the host file has the required information
HOST_FILE="$TINC_DIR/hosts/$NODE_NAME"
if ! grep -q "Subnet = $VPN_IP/32" "$HOST_FILE"; then
   echo "Error: Host file is missing subnet information!"
   exit 1
fi

if [ -n "$HOSTNAME" ] && ! grep -q "Address = $HOSTNAME" "$HOST_FILE"; then
   echo "Error: Host file is missing hostname information!"
   exit 1
fi

if ! grep -q "BEGIN RSA PUBLIC KEY" "$HOST_FILE"; then
   echo "Error: Host file is missing RSA public key!"
   exit 1
fi

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" | tee -a /etc/sysctl.conf
sysctl -p

echo "Node $NODE_NAME setup complete!"
