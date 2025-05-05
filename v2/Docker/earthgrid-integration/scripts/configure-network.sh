#!/bin/bash
# configure-network.sh
# Common network configuration script for all containers
# Handles setup of shared network parameters and validation
#
# This script:
# 1. Sets up common network environment variables
# 2. Ensures VPN is properly configured
# 3. Resolves node IP addresses
# 4. Makes network information available to Tahoe services

set -e

# Configuration
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
NODE_NAME="${NODE_NAME:-node1}"
MANIFEST_DIR="${MANIFEST_DIR:-/var/lib/earthgrid/manifest}"
MANIFEST_FILE="${MANIFEST_DIR}/manifest.yaml"
CONFIG_DIR="/var/lib/earthgrid/network-config"
LOG_FILE="/var/log/earthgrid/network-config.log"
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

# Create configuration directory
mkdir -p "$CONFIG_DIR"

# Extract VPN network CIDR from manifest
get_vpn_network() {
  if [ ! -f "$MANIFEST_FILE" ]; then
    error "Manifest file not found: $MANIFEST_FILE"
    return 1
  fi
  
  if grep -q "vpn_network:" "$MANIFEST_FILE"; then
    grep -oP 'vpn_network:\s*\K[^\s]+' "$MANIFEST_FILE"
  else
    echo "10.100.0.0/16"  # Default if not specified
  fi
}

# Extract network domain from manifest
get_network_domain() {
  if [ ! -f "$MANIFEST_FILE" ]; then
    error "Manifest file not found: $MANIFEST_FILE"
    return 1
  fi
  
  if grep -q "domain:" "$MANIFEST_FILE"; then
    grep -oP 'domain:\s*\K[^\s]+' "$MANIFEST_FILE"
  else
    echo "grid.earth"  # Default if not specified
  fi
}

# Extract role information for current node
get_node_roles() {
  if [ ! -f "$MANIFEST_FILE" ]; then
    error "Manifest file not found: $MANIFEST_FILE"
    return 1
  fi
  
  # Find the section for this node
  local start_line
  start_line=$(grep -n "  - name: $NODE_NAME$" "$MANIFEST_FILE" | cut -d: -f1)
  if [ -z "$start_line" ]; then
    error "Node $NODE_NAME not found in manifest"
    return 1
  fi
  
  # Extract role information - look for roles section
  local roles_line
  roles_line=$(tail -n +"$start_line" "$MANIFEST_FILE" | grep -n "roles:" | head -n 1 | cut -d: -f1)
  if [ -z "$roles_line" ]; then
    log "No roles section found for node $NODE_NAME"
    return 0
  fi
  
  # Extract roles until we hit the next property or node
  local roles_start=$((start_line + roles_line))
  tail -n +$roles_start "$MANIFEST_FILE" | 
    sed -n '/^      - /p' | 
    grep -oP '- \K.*' | 
    while read -r role; do
      echo "$role"
    done
}

# Check if the current node has a specific role
has_role() {
  local role="$1"
  get_node_roles | grep -q "^$role$"
}

# Wait for Tinc VPN to be ready before proceeding
wait_for_vpn() {
  log "Waiting for VPN to be ready..."
  
  # Try to run the validation script directly if it exists
  if [ -f "$SCRIPT_DIR/validate-vpn-network.sh" ]; then
    if "$SCRIPT_DIR/validate-vpn-network.sh"; then
      log "VPN validation passed"
      return 0
    else
      error "VPN validation failed"
      return 1
    fi
  fi
  
  # Fallback: check for a status file in case the script was run elsewhere
  local vpn_status_file="/var/lib/earthgrid/vpn_status"
  local max_wait=30
  local wait_count=0
  
  while [ $wait_count -lt $max_wait ]; do
    if [ -f "$vpn_status_file" ] && grep -q "VPN_READY=true" "$vpn_status_file"; then
      log "VPN is ready based on status file"
      return 0
    fi
    
    log "Waiting for VPN to be ready (attempt $((wait_count + 1))/$max_wait)..."
    sleep 10
    wait_count=$((wait_count + 1))
  done
  
  log "Warning: Timed out waiting for VPN status file. Proceeding anyway."
  return 0  # Proceed even if we can't confirm VPN is ready
}

# Setup node IP resolution
setup_ip_resolution() {
  log "Setting up node IP resolution..."
  
  # Try to run the resolution script directly if it exists
  if [ -f "$SCRIPT_DIR/resolve-node-ips.sh" ]; then
    if "$SCRIPT_DIR/resolve-node-ips.sh" update; then
      log "Node IP resolution setup completed"
      return 0
    else
      error "Node IP resolution setup failed"
      return 1
    fi
  fi
  
  log "Warning: IP resolution script not found. Manual IP configuration may be needed."
  return 0  # Proceed even if we can't run the resolution script
}

# Write network configuration parameters to a file for other scripts
write_network_config() {
  local config_file="$CONFIG_DIR/network.env"
  
  log "Writing network configuration to $config_file"
  
  # Create the config file
  mkdir -p "$(dirname "$config_file")"
  
  # Get the network parameters
  local vpn_network
  vpn_network=$(get_vpn_network)
  local network_domain
  network_domain=$(get_network_domain)
  
  # Write configuration
  cat > "$config_file" << EOF
# EarthGrid Network Configuration
# Generated: $(date)
# Node: $NODE_NAME

EARTHGRID_VPN_NETWORK="$vpn_network"
EARTHGRID_DOMAIN="$network_domain"
EOF

  # Add role information
  echo -n "EARTHGRID_ROLES=\"" >> "$config_file"
  get_node_roles | tr '\n' ' ' >> "$config_file"
  echo "\"" >> "$config_file"
  
  log "Network configuration file created: $config_file"
  return 0
}

# Main function to configure the network
configure_network() {
  log "Starting network configuration for node $NODE_NAME"
  
  if wait_for_vpn && 
     setup_ip_resolution && 
     write_network_config; then
    log "Network configuration completed successfully"
    # Touch a status file to indicate success
    touch "$CONFIG_DIR/network_configured"
    return 0
  else
    error "Network configuration failed"
    return 1
  fi
}

# Execute configuration
configure_network
exit $?