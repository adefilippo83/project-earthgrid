#!/bin/bash

# Function for logging
log() {
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [STORAGE-MONITOR] $1"
}

log "Starting storage monitor"

STORAGE_DIR="/storage"
INTERVAL=${MONITOR_INTERVAL:-300}  # Default to checking every 5 minutes

# Main monitoring loop
while true; do
    # Calculate storage usage
    TOTAL_SPACE=$(df -h $STORAGE_DIR | awk 'NR==2 {print $2}')
    USED_SPACE=$(df -h $STORAGE_DIR | awk 'NR==2 {print $3}')
    AVAIL_SPACE=$(df -h $STORAGE_DIR | awk 'NR==2 {print $4}')
    USAGE_PERCENT=$(df -h $STORAGE_DIR | awk 'NR==2 {print $5}')
    
    # Log storage statistics
    log "Storage Usage: $USED_SPACE used of $TOTAL_SPACE total ($USAGE_PERCENT) - $AVAIL_SPACE available"
    
    # Check if storage is getting too full (>90%)
    USAGE_NUM=$(echo $USAGE_PERCENT | tr -d '%')
    if [ "$USAGE_NUM" -gt 90 ]; then
        log "WARNING: Storage is getting full ($USAGE_PERCENT)"
    fi
    
    # Check if Tahoe process is still running
    if ! pgrep -f "tahoe run" > /dev/null; then
        log "WARNING: Tahoe process not running!"
    fi
    
    # Check for failed uploads/downloads in the logs (simplified example)
    ERRORS=$(grep -c "ERROR" /var/log/earthgrid/tahoe-storage.log 2>/dev/null || echo "0")
    if [ "$ERRORS" -gt 0 ]; then
        log "WARNING: Detected $ERRORS errors in Tahoe logs"
    fi
    
    # Sleep until next check
    sleep $INTERVAL
done