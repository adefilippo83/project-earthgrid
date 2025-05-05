#!/bin/bash
set -e

# Function for logging
log() {
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [TAHOE-INTRODUCER-RUN] $1"
}

log "Starting Tahoe-LAFS introducer node"

# Directory for tahoe configuration
TAHOE_DIR="/var/lib/tahoe-introducer"

# Ensure setup has been run
if [ ! -f "$TAHOE_DIR/tahoe.cfg" ]; then
    log "ERROR: Tahoe introducer configuration not found. Run setup first."
    exit 1
fi

# Start Tahoe introducer in foreground mode
log "Running tahoe introducer..."
cd $TAHOE_DIR
exec tahoe run --nodaemon