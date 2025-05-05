#!/bin/bash
set -e

# Function for logging
log() {
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [TAHOE-CLIENT-SETUP] $1"
}

log "Setting up Tahoe-LAFS client node: $NODE_NAME"

# Directory for tahoe configuration
TAHOE_DIR="/var/lib/tahoe-client"

# Check if tahoe client is already created
if [ -f "$TAHOE_DIR/tahoe.cfg" ]; then
    log "Tahoe client node already exists, checking configuration..."
else
    log "Creating new Tahoe client node..."
    # Create a new Tahoe client node
    tahoe create-client --nickname="$NICKNAME" "$TAHOE_DIR"
    log "Tahoe client node created"
fi

# Configure the tahoe client using the template
log "Configuring tahoe client..."

# Update tahoe.cfg with our template
cat /app/config/tahoe.cfg.template | \
  sed "s|%NODE_NAME%|$NODE_NAME|g" | \
  sed "s|%CLIENT_PORT%|$CLIENT_PORT|g" | \
  sed "s|%SHARES_NEEDED%|$SHARES_NEEDED|g" | \
  sed "s|%SHARES_HAPPY%|$SHARES_HAPPY|g" | \
  sed "s|%SHARES_TOTAL%|$SHARES_TOTAL|g" | \
  sed "s|%NICKNAME%|$NICKNAME|g" > $TAHOE_DIR/tahoe.cfg

# If INTRODUCER_FURL is provided, add it to the private/introducers.yaml file
if [ ! -z "$INTRODUCER_FURL" ]; then
    mkdir -p $TAHOE_DIR/private
    log "Adding introducer: $INTRODUCER_FURL"
    cat > $TAHOE_DIR/private/introducers.yaml << EOF
introducers:
  main:
    furl: $INTRODUCER_FURL
EOF
fi

# Create default web static directory
mkdir -p $TAHOE_DIR/public_html
echo "<html><body><h1>Earthgrid Tahoe-LAFS Client</h1></body></html>" > $TAHOE_DIR/public_html/index.html

# Create FUSE mount point
mkdir -p /mnt/tahoe

# Set proper permissions
chmod -R 755 $TAHOE_DIR

log "Tahoe client setup completed"