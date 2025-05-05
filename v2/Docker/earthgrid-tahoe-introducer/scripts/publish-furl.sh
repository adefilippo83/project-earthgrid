#!/bin/bash

# Function for logging
log() {
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [FURL-PUBLISHER] $1"
}

log "Starting FURL publisher service"

TAHOE_DIR="/var/lib/tahoe-introducer"
FURL_FILE="$TAHOE_DIR/private/introducer.furl"
PUBLISH_INTERVAL=${PUBLISH_INTERVAL:-300}  # Default to publishing every 5 minutes

# Wait for the FURL file to be created
log "Waiting for introducer FURL to be generated..."
timeout=30
while [ ! -f "$FURL_FILE" ] && [ $timeout -gt 0 ]; do
    sleep 1
    timeout=$((timeout-1))
done

if [ ! -f "$FURL_FILE" ]; then
    log "ERROR: Timeout waiting for FURL file"
    exit 1
fi

FURL=$(cat $FURL_FILE)
log "Introducer FURL: $FURL"

# Create a public endpoint for the FURL
mkdir -p $TAHOE_DIR/public_html
echo "$FURL" > $TAHOE_DIR/public_html/introducer.furl

# If we have a manifest repository path, update the manifest with our FURL
MANIFEST_DIR=${MANIFEST_DIR:-/var/lib/earthgrid/manifest}
MANIFEST_FILE="$MANIFEST_DIR/manifest.yaml"

update_manifest() {
    if [ -f "$MANIFEST_FILE" ]; then
        log "Updating manifest with introducer FURL..."
        # This is a simple approach - for a real implementation, use a YAML parser
        # Here we just check if the introducer_furl field exists and update it
        if grep -q "introducer_furl:" "$MANIFEST_FILE"; then
            # Replace existing value
            sed -i "s|introducer_furl:.*|introducer_furl: $FURL|" "$MANIFEST_FILE"
        else
            # Add new value at the end
            echo "introducer_furl: $FURL" >> "$MANIFEST_FILE"
        fi
        log "Manifest updated"
    else
        log "WARNING: Manifest file not found at $MANIFEST_FILE"
    fi
}

# Initial update
update_manifest

# Main loop to periodically check and update
while true; do
    log "Checking FURL status..."
    
    # Verify the introducer is still running
    if ! pgrep -f "tahoe run" > /dev/null; then
        log "WARNING: Tahoe introducer not running!"
    fi
    
    # Check if the FURL has changed (unlikely but possible)
    if [ -f "$FURL_FILE" ]; then
        NEW_FURL=$(cat $FURL_FILE)
        if [ "$NEW_FURL" != "$FURL" ]; then
            log "FURL has changed, updating..."
            FURL=$NEW_FURL
            echo "$FURL" > $TAHOE_DIR/public_html/introducer.furl
            update_manifest
        fi
    else
        log "WARNING: FURL file no longer exists!"
    fi
    
    # Sleep until next check
    sleep $PUBLISH_INTERVAL
done