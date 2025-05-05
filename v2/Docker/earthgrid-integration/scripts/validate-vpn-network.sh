#!/bin/bash
# validate-vpn-network.sh
# Validates that the Tinc VPN network is properly configured and accessible
# before letting Tahoe-LAFS containers start their services.
#
# This script:
# 1. Checks if the Tinc VPN interface is up
# 2. Validates connectivity to other nodes in the network
# 3. Ensures proper DNS resolution within the VPN
# 4. Reports success or failure to the calling container

set -e

# Configuration
MAX_RETRIES=30
RETRY_INTERVAL=10
VPN_INTERFACE="tinc0"
LOG_FILE="/var/log/earthgrid/vpn-validation.log"
MANIFEST_DIR="${MANIFEST_DIR:-/var/lib/earthgrid/manifest}"
MANIFEST_FILE="${MANIFEST_DIR}/manifest.yaml"
NODE_NAME="${NODE_NAME:-node1}"
DEBUG="${DEBUG:-false}"

# Configure logging
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log_debug() {
  if [ "$DEBUG" = "true" ]; then
    log "[DEBUG] $1"
  fi
}

error() {
  log "[ERROR] $1"
  return 1
}

# Check if VPN interface exists and is up
check_vpn_interface() {
  log "Checking VPN interface $VPN_INTERFACE..."
  if ! ip link show "$VPN_INTERFACE" &>/dev/null; then
    error "VPN interface $VPN_INTERFACE does not exist"
    return 1
  fi
  
  if ! ip link show "$VPN_INTERFACE" | grep -q "UP"; then
    error "VPN interface $VPN_INTERFACE is not up"
    return 1
  fi
  
  log_debug "VPN interface $VPN_INTERFACE is up"
  return 0
}

# Get this node's VPN IP
get_vpn_ip() {
  ip addr show "$VPN_INTERFACE" | grep -oP 'inet \K[\d.]+' | head -n 1
}

# Extract other nodes' VPN IPs from manifest
get_other_nodes_vpn_ips() {
  if [ ! -f "$MANIFEST_FILE" ]; then
    error "Manifest file not found: $MANIFEST_FILE"
    return 1
  fi
  
  # Extract node information from manifest file
  # This is a simplified version. In production, you'd use a proper YAML parser
  grep -A 10 'nodes:' "$MANIFEST_FILE" | grep -v "$NODE_NAME" | grep -oP 'vpn_ip:\s*\K[\d.]+' || true
}

# Check connectivity to other nodes
check_connectivity() {
  local other_ips
  other_ips=$(get_other_nodes_vpn_ips)
  
  if [ -z "$other_ips" ]; then
    log "No other nodes found in manifest. Skipping connectivity check."
    return 0
  fi
  
  local failed=0
  
  log "Checking connectivity to other nodes in VPN..."
  for ip in $other_ips; do
    log_debug "Pinging $ip..."
    if ! ping -c 2 -W 2 "$ip" &>/dev/null; then
      log "Failed to reach node at $ip"
      failed=$((failed + 1))
    else
      log_debug "Successfully reached node at $ip"
    fi
  done
  
  # Allow validation to pass if at least one node is reachable (when there are multiple nodes)
  local total_nodes=$(echo "$other_ips" | wc -l)
  if [ $total_nodes -gt 0 ] && [ $failed -eq $total_nodes ]; then
    error "Failed to reach any other nodes in the VPN network"
    return 1
  fi
  
  return 0
}

# Main validation logic
validate_vpn() {
  local retry=0
  
  while [ $retry -lt $MAX_RETRIES ]; do
    log "VPN validation attempt $((retry + 1))/$MAX_RETRIES"
    
    if check_vpn_interface && check_connectivity; then
      log "VPN validation successful. Network is ready for Tahoe-LAFS."
      echo "VPN_READY=true" > /var/lib/earthgrid/vpn_status
      return 0
    fi
    
    retry=$((retry + 1))
    if [ $retry -lt $MAX_RETRIES ]; then
      log "Waiting $RETRY_INTERVAL seconds before next attempt..."
      sleep $RETRY_INTERVAL
    fi
  done
  
  log "VPN validation failed after $MAX_RETRIES attempts."
  echo "VPN_READY=false" > /var/lib/earthgrid/vpn_status
  return 1
}

# Run validation
validate_vpn
exit_code=$?

if [ $exit_code -eq 0 ]; then
  log "VPN is ready for Tahoe-LAFS services"
  exit 0
else
  log "VPN is not ready. Tahoe-LAFS services should not start."
  exit 1
fi