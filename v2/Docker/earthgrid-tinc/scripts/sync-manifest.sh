#!/bin/bash
set -e

# Log function
log() {
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [SYNC-MANIFEST] $1"
}

log "Starting manifest synchronization from GitHub..."

# Variables
MANIFEST_DIR="/var/lib/earthgrid/manifest"
MANIFEST_REPO_DIR="/var/lib/earthgrid/manifest-repo"
BRANCH="${GITHUB_BRANCH:-main}"
MANIFEST_FILE="${MANIFEST_FILENAME:-manifest.yaml}"

# Clone or update the repository
if [ ! -d "$MANIFEST_REPO_DIR/.git" ]; then
    log "Initial repository clone..."
    git clone --depth 1 -b $BRANCH https://github.com/$GITHUB_REPO.git $MANIFEST_REPO_DIR
else
    log "Updating existing repository..."
    cd $MANIFEST_REPO_DIR
    git fetch
    git reset --hard origin/$BRANCH
fi

# Copy manifest file to the standard location
log "Copying manifest file to working location..."
mkdir -p $MANIFEST_DIR
cp $MANIFEST_REPO_DIR/manifest/$MANIFEST_FILE $MANIFEST_DIR/$MANIFEST_FILE

# Verify manifest file exists
if [ ! -f "$MANIFEST_DIR/$MANIFEST_FILE" ]; then
    log "ERROR: Manifest file not found at $MANIFEST_DIR/$MANIFEST_FILE"
    exit 1
fi

log "Processing nodes from manifest..."

# Extract list of nodes from manifest
NODES=$(python3 -c "
import yaml, sys
try:
    with open('$MANIFEST_DIR/$MANIFEST_FILE', 'r') as f:
        manifest = yaml.safe_load(f)
    for node in manifest['nodes']:
        print(node['name'])
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
")

# Connect to public nodes
PUBLIC_NODES=$(python3 -c "
import yaml, sys
try:
    with open('$MANIFEST_DIR/$MANIFEST_FILE', 'r') as f:
        manifest = yaml.safe_load(f)
    for node in manifest['nodes']:
        if node.get('is_publicly_accessible', False) and node['name'] != '$NODE_NAME':
            print(node['name'])
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
")

# Update tinc.conf with ConnectTo directives for public nodes
if [ ! -z "$PUBLIC_NODES" ]; then
    log "Updating ConnectTo directives for public nodes..."
    # Remove existing ConnectTo lines
    sed -i '/^ConnectTo/d' /etc/tinc/earthgrid/tinc.conf
    
    # Add new ConnectTo lines
    for NODE in $PUBLIC_NODES; do
        log "Adding ConnectTo directive for $NODE"
        echo "ConnectTo = $NODE" >> /etc/tinc/earthgrid/tinc.conf
    done
fi

# Process each node
for NODE in $NODES; do
    if [ "$NODE" = "$NODE_NAME" ]; then
        log "Skipping self ($NODE_NAME)"
        continue
    fi
    
    log "Processing node: $NODE"
    
    # Extract node's GPG key ID from manifest
    NODE_GPG_KEY=$(python3 -c "
    import yaml, sys
    try:
        with open('$MANIFEST_DIR/$MANIFEST_FILE', 'r') as f:
            manifest = yaml.safe_load(f)
        for node in manifest['nodes']:
            if node['name'] == '$NODE':
                print(node.get('gpg_key_id', ''))
                break
    except Exception as e:
        print(f'Error: {e}', file=sys.stderr)
        sys.exit(1)
    ")
    
    if [ -z "$NODE_GPG_KEY" ]; then
        log "WARNING: No GPG key defined for node $NODE, skipping"
        continue
    fi
    
    # Download GPG key if not present locally
    if ! gpg --list-keys "$NODE_GPG_KEY" > /dev/null 2>&1; then
        log "Downloading GPG key $NODE_GPG_KEY for node $NODE..."
        gpg --keyserver keys.openpgp.org --recv-keys "$NODE_GPG_KEY"
        
        if [ $? -ne 0 ]; then
            log "WARNING: Failed to download GPG key $NODE_GPG_KEY for node $NODE"
            continue
        fi
    fi
    
    # Extract node's connection information from manifest
    NODE_INFO=$(python3 -c "
    import yaml, json, sys
    try:
        with open('$MANIFEST_DIR/$MANIFEST_FILE', 'r') as f:
            manifest = yaml.safe_load(f)
        for node in manifest['nodes']:
            if node['name'] == '$NODE':
                print(json.dumps({
                    'vpn_ip': node.get('vpn_ip', ''),
                    'hostname': node.get('hostname', ''),
                    'is_public': node.get('is_publicly_accessible', False)
                }))
                break
    except Exception as e:
        print(f'Error: {e}', file=sys.stderr)
        sys.exit(1)
    ")
    
    # Create or update host file for the node
    NODE_VPN_IP=$(echo $NODE_INFO | jq -r '.vpn_ip')
    NODE_HOSTNAME=$(echo $NODE_INFO | jq -r '.hostname')
    NODE_IS_PUBLIC=$(echo $NODE_INFO | jq -r '.is_public')
    
    log "Creating/updating host file for $NODE..."
    
    if [ -f "/etc/tinc/earthgrid/hosts/$NODE" ]; then
        # Backup existing host file
        cp "/etc/tinc/earthgrid/hosts/$NODE" "/etc/tinc/earthgrid/hosts/$NODE.bak"
    fi
    
    # Create basic host file
    cat > "/etc/tinc/earthgrid/hosts/$NODE" << EOF
Subnet = ${NODE_VPN_IP}/32
EOF
    
    if [ ! -z "$NODE_HOSTNAME" ] && [ "$NODE_IS_PUBLIC" = "true" ]; then
        echo "Address = $NODE_HOSTNAME" >> "/etc/tinc/earthgrid/hosts/$NODE"
        echo "Port = 655" >> "/etc/tinc/earthgrid/hosts/$NODE"
    fi
    
    log "Updated host file for $NODE"
done

# Restart tinc to apply changes if needed
if tincd -n earthgrid -k; then
    log "Reloaded Tinc configuration successfully"
else
    log "WARNING: Failed to reload Tinc configuration"
fi

log "Manifest synchronization completed successfully"