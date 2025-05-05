#!/bin/bash
set -e

# Log function
log() {
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [SETUP-TINC] $1"
}

log "Setting up Tinc VPN for node: $NODE_NAME"

# Directories for configuration
MANIFEST_DIR="/var/lib/earthgrid/manifest"
MANIFEST_REPO_DIR="/var/lib/earthgrid/manifest-repo"
mkdir -p $MANIFEST_DIR $MANIFEST_REPO_DIR

# Create base Tinc configuration
mkdir -p /etc/tinc/earthgrid/hosts

# Configure tinc.conf using template
log "Creating tinc.conf configuration..."
cat > /etc/tinc/earthgrid/tinc.conf << EOF
Name = ${NODE_NAME}
Interface = tun0
Mode = switch
AddressFamily = ipv4
Port = 655
LocalDiscovery = yes
AutoConnect = yes
PingTimeout = 30
PriorityInheritance = yes
ProcessPriority = high
EOF

# Configure local host file
log "Setting up local host configuration..."
cat > /etc/tinc/earthgrid/hosts/${NODE_NAME} << EOF
Subnet = ${INTERNAL_VPN_IP}/32
EOF

# If PUBLIC_IP is provided, add it to the host file
if [ ! -z "$PUBLIC_IP" ]; then
    if [ "$PUBLIC_IP" = "auto" ]; then
        log "Detecting public IP address..."
        PUBLIC_IP=$(curl -s https://api.ipify.org)
    fi
    log "Using public IP: $PUBLIC_IP"
    echo "Address = ${PUBLIC_IP}" >> /etc/tinc/earthgrid/hosts/${NODE_NAME}
    echo "Port = 655" >> /etc/tinc/earthgrid/hosts/${NODE_NAME}
fi

# Generate or import Tinc keys
if [ ! -f /etc/tinc/earthgrid/rsa_key.priv ]; then
    if [ ! -z "$TINC_PRIVATE_KEY" ]; then
        log "Using Tinc private key from environment variable..."
        echo "$TINC_PRIVATE_KEY" > /etc/tinc/earthgrid/rsa_key.priv
        chmod 600 /etc/tinc/earthgrid/rsa_key.priv
    elif [ -f "/run/secrets/tinc_private_key" ]; then
        log "Using Tinc private key from Docker secret..."
        cp /run/secrets/tinc_private_key /etc/tinc/earthgrid/rsa_key.priv
        chmod 600 /etc/tinc/earthgrid/rsa_key.priv
    else
        log "Generating new 4096-bit RSA key for Tinc..."
        # First create the key in the correct format
        openssl genrsa -out /etc/tinc/earthgrid/rsa_key.priv 4096
        chmod 600 /etc/tinc/earthgrid/rsa_key.priv
        # Generate the public key
        openssl rsa -in /etc/tinc/earthgrid/rsa_key.priv -pubout > /etc/tinc/earthgrid/rsa_key.pub
        # Add the key to the host file
        echo "-----BEGIN RSA PUBLIC KEY-----" >> /etc/tinc/earthgrid/hosts/${NODE_NAME}
        cat /etc/tinc/earthgrid/rsa_key.pub | grep -v "PUBLIC KEY" >> /etc/tinc/earthgrid/hosts/${NODE_NAME}
        echo "-----END RSA PUBLIC KEY-----" >> /etc/tinc/earthgrid/hosts/${NODE_NAME}
    fi
fi

# Export GPG public key
log "Exporting GPG public key to host file directory..."
gpg --armor --export "$GPG_KEY_ID" > /etc/tinc/earthgrid/hosts/${NODE_NAME}.gpg

# Sign the host file with GPG
log "Signing host file with GPG key $GPG_KEY_ID..."
gpg --detach-sign -a --default-key "$GPG_KEY_ID" /etc/tinc/earthgrid/hosts/${NODE_NAME}

# Create tinc-up script
log "Creating tinc-up script..."
cat > /etc/tinc/earthgrid/tinc-up << EOF
#!/bin/sh
ip link set \$INTERFACE up
ip addr add ${INTERNAL_VPN_IP}/16 dev \$INTERFACE
EOF
chmod +x /etc/tinc/earthgrid/tinc-up

# Create tinc-down script
log "Creating tinc-down script..."
cat > /etc/tinc/earthgrid/tinc-down << EOF
#!/bin/sh
ip addr del ${INTERNAL_VPN_IP}/16 dev \$INTERFACE
ip link set \$INTERFACE down
EOF
chmod +x /etc/tinc/earthgrid/tinc-down

# Create host-up script to verify GPG signatures
log "Creating host-up script for GPG verification..."
cat > /etc/tinc/earthgrid/host-up << EOF
#!/bin/bash
NODE=\$1
log() {
    echo "\$(date -u +"%Y-%m-%dT%H:%M:%SZ") [HOST-UP] \$1"
}

log "Verifying connection from node: \$NODE"

# Skip self-verification
if [ "\$NODE" = "$NODE_NAME" ]; then
    log "Skipping self-verification"
    exit 0
fi

# Check if signature file exists
if [ ! -f "/etc/tinc/earthgrid/hosts/\$NODE.sig" ]; then
    log "ERROR: No signature file found for \$NODE"
    exit 1
fi

# Find key ID from manifest
MANIFEST_FILE="/var/lib/earthgrid/manifest/manifest.yaml"
if [ ! -f "\$MANIFEST_FILE" ]; then
    log "ERROR: Manifest file not found"
    exit 1
fi

NODE_GPG_KEY=\$(grep -A5 "name: \$NODE" \$MANIFEST_FILE | grep "gpg_key_id" | awk '{print \$2}')
if [ -z "\$NODE_GPG_KEY" ]; then
    log "ERROR: GPG key ID for \$NODE not found in manifest"
    exit 1
fi

# Verify signature
if gpg --verify "/etc/tinc/earthgrid/hosts/\$NODE.sig" "/etc/tinc/earthgrid/hosts/\$NODE" 2>/dev/null; then
    log "Node \$NODE authenticated successfully with key \$NODE_GPG_KEY"
    exit 0
else
    log "ERROR: GPG signature verification failed for \$NODE"
    exit 1
fi
EOF
chmod +x /etc/tinc/earthgrid/host-up

log "Tinc VPN setup completed successfully"