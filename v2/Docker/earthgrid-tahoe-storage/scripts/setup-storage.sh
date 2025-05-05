#!/bin/bash
set -e

# Function for logging
log() {
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [TAHOE-STORAGE-SETUP] $1"
}

log "Setting up Tahoe-LAFS storage node: $NODE_NAME"

# Directory for tahoe configuration
TAHOE_DIR="/var/lib/tahoe-storage"
STORAGE_DIR="/storage"

# Make sure storage directory exists
mkdir -p $STORAGE_DIR

# Check if tahoe storage node is already created
if [ -f "$TAHOE_DIR/tahoe.cfg" ]; then
    log "Tahoe storage node already exists, checking configuration..."
else
    log "Creating new Tahoe storage node..."
    # Create a new Tahoe storage node
    tahoe create-node --nickname="$NICKNAME" $TAHOE_DIR
    log "Tahoe storage node created"
fi

# Configure the tahoe storage node using the template
log "Configuring tahoe storage node..."

# Update tahoe.cfg with our template
cat /app/config/tahoe.cfg.template | \
  sed "s|%NODE_NAME%|$NODE_NAME|g" | \
  sed "s|%STORAGE_PORT%|$STORAGE_PORT|g" | \
  sed "s|%STORAGE_DIR%|$STORAGE_DIR|g" | \
  sed "s|%RESERVED_SPACE%|$RESERVED_SPACE|g" | \
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

# Create simple status page
mkdir -p $TAHOE_DIR/public_html
cat > $TAHOE_DIR/public_html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Earthgrid Storage Node: $NODE_NAME</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #3498db; }
        .info { margin-top: 20px; }
        .status { margin-top: 10px; padding: 10px; background-color: #ecf0f1; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>Earthgrid Storage Node</h1>
    <div class="info">
        <p><strong>Node Name:</strong> $NODE_NAME</p>
        <p><strong>Storage Allocation:</strong> $RESERVED_SPACE</p>
    </div>
    <div class="status" id="status">
        <p>Status: Running</p>
        <p>Started: $(date)</p>
    </div>
</body>
</html>
EOF

# Set proper permissions
chmod -R 755 $TAHOE_DIR
chmod -R 755 $STORAGE_DIR

log "Tahoe storage node setup completed"