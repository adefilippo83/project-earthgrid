#!/bin/bash

set -e

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root. Try 'sudo $0'"
   exit 1
fi

REPO_DIR="/opt/project-earthgrid"

# Install Tahoe-LAFS on all nodes
echo "Installing Tahoe-LAFS on all nodes..."
bash "$REPO_DIR/tahoe/scripts/install-tahoe.sh"

# Identify the introducer node
INTRODUCER_NODE=$($PYTHON_CMD -c "
import yaml, sys
try:
   with open('$REPO_DIR/tahoe/inventory/tahoe-nodes.yml', 'r') as f:
       config = yaml.safe_load(f)
   for node in config['nodes']:
       if 'introducer' in node.get('tahoe_roles', []):
           print(node['name'])
           break
   else:
       print('ERROR: No introducer node defined')
       sys.exit(1)
except Exception as e:
   print(f'Error: {e}', file=sys.stderr)
   sys.exit(1)
")

if [ "$INTRODUCER_NODE" == "ERROR: No introducer node defined" ]; then
   echo "Error: No introducer node defined in inventory"
   exit 1
fi

echo "Setting up introducer node on $INTRODUCER_NODE..."
bash "$REPO_DIR/tahoe/scripts/setup-introducer.sh" "$INTRODUCER_NODE"

# Wait for introducer FURL to be published
while [ ! -f "$REPO_DIR/tahoe/config/introducer.furl" ]; do
   echo "Waiting for introducer FURL..."
   sleep 5
done

echo "Introducer is now ready. Setting up storage nodes..."

# Set up storage nodes
for node_name in $($PYTHON_CMD -c "
import yaml, sys
try:
   with open('$REPO_DIR/tahoe/inventory/tahoe-nodes.yml', 'r') as f:
       config = yaml.safe_load(f)
   for node in config['nodes']:
       if 'storage' in node.get('tahoe_roles', []) and node['name'] != '$INTRODUCER_NODE':
           print(node['name'])
except Exception as e:
   print(f'Error: {e}', file=sys.stderr)
   sys.exit(1)
"); do
   echo "Setting up storage node on $node_name..."
   bash "$REPO_DIR/tahoe/scripts/setup-storage-node.sh" "$node_name"
done

echo "Setting up client and web nodes..."

# Set up client and web nodes
for node_name in $($PYTHON_CMD -c "
import yaml, sys
try:
   with open('$REPO_DIR/tahoe/inventory/tahoe-nodes.yml', 'r') as f:
       config = yaml.safe_load(f)
   for node in config['nodes']:
       if 'client' in node.get('tahoe_roles', []) or 'web' in node.get('tahoe_roles', []):
           print(node['name'])
except Exception as e:
   print(f'Error: {e}', file=sys.stderr)
   sys.exit(1)
"); do
   echo "Setting up client node on $node_name..."
   bash "$REPO_DIR/tahoe/scripts/setup-client-node.sh" "$node_name"
   
   if $PYTHON_CMD -c "
   import yaml, sys
   try:
      with open('$REPO_DIR/tahoe/inventory/tahoe-nodes.yml', 'r') as f:
          config = yaml.safe_load(f)
      for node in config['nodes']:
          if node['name'] == '$node_name' and 'web' in node.get('tahoe_roles', []):
              print('true')
              break
      else:
          print('false')
   except Exception as e:
      print('false')
   " | grep -q "true"; then
      echo "Setting up web gateway on $node_name..."
      bash "$REPO_DIR/tahoe/scripts/setup-web-gateway.sh" "$node_name"
   fi
done

echo "Tahoe-LAFS grid bootstrap complete!"
