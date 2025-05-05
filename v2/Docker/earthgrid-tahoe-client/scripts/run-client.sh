#!/bin/bash
set -e

# Function for logging
log() {
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [TAHOE-CLIENT-RUN] $1"
}

log "Starting Tahoe-LAFS client node"

# Directory for tahoe configuration
TAHOE_DIR="/var/lib/tahoe-client"

# Ensure setup has been run
if [ ! -f "$TAHOE_DIR/tahoe.cfg" ]; then
    log "ERROR: Tahoe client configuration not found. Run setup first."
    exit 1
fi

# Start Tahoe client in foreground mode
log "Running tahoe client..."
cd $TAHOE_DIR
exec tahoe run --nodaemon