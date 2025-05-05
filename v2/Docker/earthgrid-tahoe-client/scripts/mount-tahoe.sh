#!/bin/bash
set -e

# Function for logging
log() {
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [TAHOE-MOUNT] $1"
}

log "Mounting Tahoe-LAFS as FUSE filesystem"

# Directory for tahoe configuration
TAHOE_DIR="/var/lib/tahoe-client"
MOUNT_POINT="/mnt/tahoe"

# Ensure setup has been run and client is running
if [ ! -f "$TAHOE_DIR/tahoe.cfg" ]; then
    log "ERROR: Tahoe client configuration not found. Run setup first."
    exit 1
fi

# Create mount point if it doesn't exist
mkdir -p $MOUNT_POINT

# Check if client is running
if ! pgrep -f "tahoe run" > /dev/null; then
    log "WARNING: Tahoe client doesn't seem to be running"
fi

# Mount Tahoe FUSE filesystem
log "Mounting at $MOUNT_POINT"
tahoe mount $MOUNT_POINT