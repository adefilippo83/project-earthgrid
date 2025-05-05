#!/bin/bash
set -e

# Function for logging
log() {
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [TAHOE-INTRODUCER-SETUP] $1"
}

log "Setting up Tahoe-LAFS introducer node: $NODE_NAME"

# Directory for tahoe configuration
TAHOE_DIR="/var/lib/tahoe-introducer"

# Check if tahoe introducer is already created
if [ -f "$TAHOE_DIR/tahoe.cfg" ]; then
    log "Tahoe introducer already exists, checking configuration..."
else
    log "Creating new Tahoe introducer..."
    # Create a new Tahoe introducer node
    tahoe create-introducer --nickname="$NICKNAME" $TAHOE_DIR
    log "Tahoe introducer created"
fi

# Configure the tahoe introducer using the template
log "Configuring tahoe introducer..."

# Update tahoe.cfg with our template
cat /app/config/tahoe.cfg.template | \
  sed "s|%NODE_NAME%|$NODE_NAME|g" | \
  sed "s|%INTRODUCER_PORT%|$INTRODUCER_PORT|g" | \
  sed "s|%NICKNAME%|$NICKNAME|g" > $TAHOE_DIR/tahoe.cfg

# Create simple status page
mkdir -p $TAHOE_DIR/public_html
cat > $TAHOE_DIR/public_html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Earthgrid Introducer Node: $NODE_NAME</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #3498db; }
        .info { margin-top: 20px; }
        .status { margin-top: 10px; padding: 10px; background-color: #ecf0f1; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>Earthgrid Introducer Node</h1>
    <div class="info">
        <p><strong>Node Name:</strong> $NODE_NAME</p>
        <p><strong>FURL published at:</strong> /var/lib/tahoe-introducer/private/introducer.furl</p>
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

log "Tahoe introducer setup completed"

# Display the FURL (but wait for it to be created first)
log "Waiting for introducer FURL to be generated..."
FURL_FILE="$TAHOE_DIR/private/introducer.furl"
timeout=30
while [ ! -f "$FURL_FILE" ] && [ $timeout -gt 0 ]; do
    sleep 1
    timeout=$((timeout-1))
done

if [ -f "$FURL_FILE" ]; then
    log "Introducer FURL: $(cat $FURL_FILE)"
else
    log "WARNING: Timeout waiting for FURL file"
fi