#!/bin/bash
# This script deploys configuration updates to all nodes

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
TINC_CONFIG_DIR="$(dirname "$SCRIPT_DIR")"
REPO_DIR="$(dirname "$TINC_CONFIG_DIR")"
INVENTORY_FILE="$TINC_CONFIG_DIR/inventory/nodes.yml"

# Check dependencies
if ! command -v python3 &>/dev/null; then
   echo "Python 3 is required but not installed. Please install it first."
   exit 1
fi

if ! command -v sshpass &>/dev/null; then
   echo "Warning: sshpass is not installed. You'll need to enter passwords manually."
fi

# Parse node information from inventory
NODES=$(python3 -c "
import yaml, sys
try:
   with open('$INVENTORY_FILE', 'r') as f:
       config = yaml.safe_load(f)
   for node in config['nodes']:
       # Determine SSH connection hostname/IP with priority order
       if 'ssh_host' in node:
           ssh_host = node['ssh_host']
       elif 'hostname' in node:
           ssh_host = node['hostname']
       elif 'public_ip' in node:
           ssh_host = node['public_ip']
       else:
           ssh_host = node['vpn_ip']
       
       ssh_user = node.get('ssh_user', 'pi')
       print(f\"{node['name']}:{ssh_user}@{ssh_host}\")
except Exception as e:
   print(f'Error: {e}', file=sys.stderr)
   sys.exit(1)
")

# Function to deploy to a single node
deploy_to_node() {
   local node_info=$1
   local node_name=$(echo "$node_info" | cut -d':' -f1)
   local ssh_conn=$(echo "$node_info" | cut -d':' -f2)
   
   echo "Deploying to $node_name ($ssh_conn)..."
   
   # Check if we can SSH without password (using key authentication)
   if ssh -o BatchMode=yes -o ConnectTimeout=5 "$ssh_conn" "echo Connected successfully" &>/dev/null; then
       SSH_CMD="ssh"
   elif command -v sshpass &>/dev/null && [ -n "$SSH_PASSWORD" ]; then
       SSH_CMD="sshpass -e ssh"
   else
       SSH_CMD="ssh"
       echo "Warning: No password provided and key authentication failed."
       echo "You may need to enter password multiple times."
   fi
   
   # Update git repository on the node
   $SSH_CMD "$ssh_conn" "sudo -E bash -c '
       if [ -d \"/opt/project-earthgrid\" ]; then
           cd /opt/project-earthgrid && git pull
       else
           mkdir -p /opt
           git clone https://github.com/adefilippo83/project-earthgrid.git /opt/project-earthgrid
       fi
   '"
   
   # Run the update script
   $SSH_CMD "$ssh_conn" "sudo -E bash -c '
       if [ -f \"/opt/project-earthgrid/tinc/scripts/update-config.sh\" ]; then
           bash /opt/project-earthgrid/tinc/scripts/update-config.sh
       else
           echo \"Error: update-config.sh not found on remote node\"
           exit 1
       fi
   '"
   
   echo "Deployment to $node_name complete!"
}

# Process command line options
DEPLOY_ALL=true
SPECIFIED_NODES=()

while [[ $# -gt 0 ]]; do
   case $1 in
       -n|--node)
           DEPLOY_ALL=false
           SPECIFIED_NODES+=("$2")
           shift 2
           ;;
       -p|--password)
           export SSH_PASSWORD="$2"
           shift 2
           ;;
       *)
           echo "Unknown option: $1"
           echo "Usage: $0 [-n|--node NODE_NAME] [-p|--password SSH_PASSWORD]"
           exit 1
           ;;
   esac
done

# Deploy to selected nodes
if [ "$DEPLOY_ALL" = true ]; then
   echo "Deploying to all nodes..."
   for node_info in $NODES; do
       deploy_to_node "$node_info"
   done
else
   echo "Deploying to specified nodes..."
   for node_name in "${SPECIFIED_NODES[@]}"; do
       node_info=$(echo "$NODES" | grep "^$node_name:" || echo "")
       if [ -n "$node_info" ]; then
           deploy_to_node "$node_info"
       else
           echo "Error: Node $node_name not found in inventory"
       fi
   done
fi

echo "Deployment complete!"
