#!/bin/bash
set -e

# Function for logging
log() {
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [TAHOE-STORAGE-RUN] $1"
}

log "Starting Tahoe-LAFS storage node"

# Directory for tahoe configuration
TAHOE_DIR="/var/lib/tahoe-storage"

# Ensure setup has been run
if [ ! -f "$TAHOE_DIR/tahoe.cfg" ]; then
    log "ERROR: Tahoe storage configuration not found. Run setup first."
    exit 1
fi

# Start Tahoe storage node in foreground mode
log "Running tahoe storage node..."
cd $TAHOE_DIR
exec tahoe run --nodaemon