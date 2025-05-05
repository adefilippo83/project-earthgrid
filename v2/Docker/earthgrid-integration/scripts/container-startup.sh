#!/bin/bash
# container-startup.sh
# Manages startup sequence of containers in the appropriate order
# Ensures dependencies are running before dependent services start
#
# This script:
# 1. Handles the proper startup order of containers
# 2. Waits for dependencies to be ready
# 3. Initiates network configuration before Tahoe-LAFS services start
# 4. Can be used as entrypoint for Tahoe-LAFS containers

set -e

# Configuration
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
NODE_NAME="${NODE_NAME:-node1}"
MANIFEST_DIR="${MANIFEST_DIR:-/var/lib/earthgrid/manifest}"
CONFIG_DIR="/var/lib/earthgrid/network-config"
CONTAINER_TYPE="${CONTAINER_TYPE:-unknown}"
STARTUP_TIMEOUT="${STARTUP_TIMEOUT:-180}"
HEALTHCHECK_INTERVAL="${HEALTHCHECK_INTERVAL:-5}"
LOG_FILE="/var/log/earthgrid/container-startup.log"
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

# Wait for VPN to be ready
wait_for_vpn() {
  log "Waiting for VPN to be ready..."
  
  # Try to run the validation script directly if it exists
  if [ -f "$SCRIPT_DIR/validate-vpn-network.sh" ]; then
    "$SCRIPT_DIR/validate-vpn-network.sh"
    return $?
  fi
  
  # Fallback: check for status file
  local timeout_counter=0
  while [ $timeout_counter -lt $STARTUP_TIMEOUT ]; do
    if [ -f "/var/lib/earthgrid/vpn_status" ] && 
       grep -q "VPN_READY=true" "/var/lib/earthgrid/vpn_status"; then
      log "VPN is ready"
      return 0
    fi
    
    log "VPN not ready yet. Waiting... ($timeout_counter/$STARTUP_TIMEOUT seconds)"
    sleep $HEALTHCHECK_INTERVAL
    timeout_counter=$((timeout_counter + $HEALTHCHECK_INTERVAL))
  done
  
  error "Timed out waiting for VPN to be ready"
  return 1
}

# Configure network settings
configure_network() {
  log "Configuring network for $CONTAINER_TYPE container..."
  
  # Run the network configuration script if it exists
  if [ -f "$SCRIPT_DIR/configure-network.sh" ]; then
    "$SCRIPT_DIR/configure-network.sh"
    return $?
  fi
  
  # Fallback: check for configuration status
  local timeout_counter=0
  while [ $timeout_counter -lt $STARTUP_TIMEOUT ]; do
    if [ -f "$CONFIG_DIR/network_configured" ]; then
      log "Network is configured"
      return 0
    fi
    
    log "Network not configured yet. Waiting... ($timeout_counter/$STARTUP_TIMEOUT seconds)"
    sleep $HEALTHCHECK_INTERVAL
    timeout_counter=$((timeout_counter + $HEALTHCHECK_INTERVAL))
  done
  
  error "Timed out waiting for network configuration"
  return 1
}

# Sync introducer FURL for client and storage nodes
sync_introducer_furl() {
  log "Synchronizing introducer FURL..."
  
  # Run the FURL sync script if it exists
  if [ -f "$SCRIPT_DIR/sync-introducer-furl.sh" ]; then
    "$SCRIPT_DIR/sync-introducer-furl.sh"
    return $?
  fi
  
  # Skip if script not found
  log "Introducer FURL sync script not found. Skipping."
  return 0
}

# Wait for introducer FURL to be available (for client/storage nodes)
wait_for_introducer_furl() {
  if [ "$CONTAINER_TYPE" = "introducer" ]; then
    return 0  # Introducer doesn't need to wait for itself
  fi
  
  log "Waiting for introducer FURL to be available..."
  
  local furl_cache_file="/var/lib/earthgrid/introducer_furl.cache"
  local timeout_counter=0
  
  while [ $timeout_counter -lt $STARTUP_TIMEOUT ]; do
    # First check local cache file
    if [ -f "$furl_cache_file" ] && [ -s "$furl_cache_file" ]; then
      log "Introducer FURL found in cache"
      return 0
    fi
    
    # Then check manifest
    if [ -f "$MANIFEST_DIR/manifest.yaml" ]; then
      local furl=$(grep -oP "^introducer_furl:\s*\K.*" "$MANIFEST_DIR/manifest.yaml")
      if [ -n "$furl" ] && [ "$furl" != "null" ]; then
        log "Introducer FURL found in manifest"
        return 0
      fi
    fi
    
    # If FURL is provided as environment variable, use that
    if [ -n "$INTRODUCER_FURL" ]; then
      log "Using INTRODUCER_FURL from environment"
      mkdir -p "$(dirname "$furl_cache_file")"
      echo "$INTRODUCER_FURL" > "$furl_cache_file"
      return 0
    }
    
    log "Introducer FURL not available yet. Waiting... ($timeout_counter/$STARTUP_TIMEOUT seconds)"
    sleep $HEALTHCHECK_INTERVAL
    timeout_counter=$((timeout_counter + $HEALTHCHECK_INTERVAL))
    
    # Try to sync FURL periodically during wait
    if [ $((timeout_counter % 30)) -eq 0 ]; then
      sync_introducer_furl || true
    fi
  done
  
  error "Timed out waiting for introducer FURL"
  return 1
}

# Check if the Tahoe node configuration is complete
check_tahoe_config() {
  local node_dir=""
  
  case "$CONTAINER_TYPE" in
    "client")
      node_dir="/var/lib/tahoe-client"
      ;;
    "storage")
      node_dir="/var/lib/tahoe-storage"
      ;;
    "introducer")
      node_dir="/var/lib/tahoe-introducer"
      ;;
    *)
      error "Unknown container type: $CONTAINER_TYPE"
      return 1
      ;;
  esac
  
  if [ ! -d "$node_dir" ]; then
    error "Tahoe node directory not found: $node_dir"
    return 1
  }
  
  if [ ! -f "$node_dir/tahoe.cfg" ]; then
    error "Tahoe configuration not found: $node_dir/tahoe.cfg"
    return 1
  }
  
  log "Tahoe $CONTAINER_TYPE node configuration exists"
  return 0
}

# Run appropriate setup script for the container type
run_setup_script() {
  local setup_script=""
  
  case "$CONTAINER_TYPE" in
    "client")
      setup_script="/usr/local/bin/setup-client.sh"
      ;;
    "storage")
      setup_script="/usr/local/bin/setup-storage.sh"
      ;;
    "introducer")
      setup_script="/usr/local/bin/setup-introducer.sh"
      ;;
    "tinc")
      setup_script="/usr/local/bin/setup-tinc.sh"
      ;;
    *)
      error "Unknown container type: $CONTAINER_TYPE"
      return 1
      ;;
  esac
  
  if [ -x "$setup_script" ]; then
    log "Running setup script: $setup_script"
    "$setup_script"
    return $?
  else
    error "Setup script not found or not executable: $setup_script"
    return 1
  fi
}

# Run appropriate service script for the container type
run_service_script() {
  local service_script=""
  
  case "$CONTAINER_TYPE" in
    "client")
      service_script="/usr/local/bin/run-client.sh"
      ;;
    "storage")
      service_script="/usr/local/bin/run-storage.sh"
      ;;
    "introducer")
      service_script="/usr/local/bin/run-introducer.sh"
      ;;
    "tinc")
      service_script="/usr/local/bin/run-tinc.sh"
      ;;
    *)
      error "Unknown container type: $CONTAINER_TYPE"
      return 1
      ;;
  esac
  
  if [ -x "$service_script" ]; then
    log "Running service script: $service_script"
    exec "$service_script"
  else
    error "Service script not found or not executable: $service_script"
    return 1
  fi
}

# Main startup sequence
startup_sequence() {
  log "Starting container for $CONTAINER_TYPE node: $NODE_NAME"
  
  # Validate container type
  if [ "$CONTAINER_TYPE" = "unknown" ]; then
    error "Container type not specified. Set CONTAINER_TYPE environment variable."
    return 1
  fi
  
  # Tinc VPN startup is handled separately
  if [ "$CONTAINER_TYPE" = "tinc" ]; then
    run_setup_script
    run_service_script
    return $?
  fi
  
  # For Tahoe containers, ensure VPN is ready first
  if wait_for_vpn; then
    log "VPN is ready. Continuing with startup sequence."
  else
    error "VPN is not ready. Cannot start Tahoe services."
    return 1
  fi
  
  # Configure network
  if configure_network; then
    log "Network configuration complete. Continuing with startup sequence."
  else
    error "Network configuration failed. Cannot start Tahoe services."
    return 1
  fi
  
  # For introducers, run setup and publish FURL
  if [ "$CONTAINER_TYPE" = "introducer" ]; then
    if run_setup_script; then
      sync_introducer_furl || log "Warning: Failed to publish introducer FURL"
      run_service_script
      return $?
    else
      error "Introducer setup failed."
      return 1
    fi
  fi
  
  # For client/storage nodes, wait for introducer FURL
  if wait_for_introducer_furl; then
    log "Introducer FURL is available. Continuing with startup sequence."
  else
    error "Introducer FURL is not available. Cannot start Tahoe services."
    return 1
  fi
  
  # Run setup and service scripts for client/storage
  if run_setup_script; then
    run_service_script
    return $?
  else
    error "Setup failed for $CONTAINER_TYPE node."
    return 1
  fi
}

# Execute startup sequence
startup_sequence
exit $?