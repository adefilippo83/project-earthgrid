#!/bin/bash
# sync-introducer-furl.sh
# Synchronizes the Tahoe-LAFS introducer FURL to/from the network manifest
#
# This script:
# 1. For introducers: Extracts FURL from tahoe.cfg and updates manifest
# 2. For clients/storage: Gets FURL from manifest and updates local config
# 3. Handles FURL rotation and updates

set -e

# Configuration
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
NODE_NAME="${NODE_NAME:-node1}"
MANIFEST_DIR="${MANIFEST_DIR:-/var/lib/earthgrid/manifest}"
MANIFEST_FILE="${MANIFEST_DIR}/manifest.yaml"
CONFIG_DIR="/var/lib/earthgrid/network-config"
LOG_FILE="/var/log/earthgrid/furl-sync.log"
INTRODUCER_DIR="/var/lib/tahoe-introducer"
CLIENT_DIR="/var/lib/tahoe-client"
STORAGE_DIR="/var/lib/tahoe-storage"
FURL_CACHE_FILE="/var/lib/earthgrid/introducer_furl.cache"
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

# Create needed directories
mkdir -p "$(dirname "$FURL_CACHE_FILE")"

# Get node roles
get_node_roles() {
  if [ -f "$CONFIG_DIR/network.env" ]; then
    # Extract from network config if it exists
    source "$CONFIG_DIR/network.env"
    echo "$EARTHGRID_ROLES"
  elif [ -f "$MANIFEST_FILE" ]; then
    # Find the section for this node
    local start_line=$(grep -n "  - name: $NODE_NAME$" "$MANIFEST_FILE" | cut -d: -f1)
    if [ -z "$start_line" ]; then
      error "Node $NODE_NAME not found in manifest"
      return 1
    fi
    
    # Extract role information - look for roles section
    local roles_line=$(tail -n +$start_line "$MANIFEST_FILE" | grep -n "roles:" | head -n 1 | cut -d: -f1)
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
  else
    error "Neither network config nor manifest file found"
    return 1
  fi
}

# Check if the current node has a specific role
has_role() {
  local role="$1"
  get_node_roles | grep -q "^$role$"
}

# Extract FURL from tahoe.cfg in the introducer node
extract_introducer_furl() {
  if [ ! -d "$INTRODUCER_DIR" ]; then
    error "Introducer directory not found: $INTRODUCER_DIR"
    return 1
  fi
  
  local introducer_cfg="$INTRODUCER_DIR/tahoe.cfg"
  if [ ! -f "$introducer_cfg" ]; then
    error "Introducer configuration not found: $introducer_cfg"
    return 1
  fi
  
  # Extract the FURL from the introducer's tahoe.cfg
  local furl_file="$INTRODUCER_DIR/private/introducer.furl"
  if [ -f "$furl_file" ]; then
    cat "$furl_file"
    return 0
  fi
  
  error "Could not find introducer.furl file"
  return 1
}

# Update manifest with FURL
update_manifest_furl() {
  local furl="$1"
  
  if [ -z "$furl" ]; then
    error "No FURL provided to update manifest"
    return 1
  fi
  
  if [ ! -f "$MANIFEST_FILE" ]; then
    error "Manifest file not found: $MANIFEST_FILE"
    return 1
  fi
  
  log "Updating manifest with introducer FURL"
  
  # Check if introducer_furl line exists in manifest
  if grep -q "^introducer_furl:" "$MANIFEST_FILE"; then
    # Update existing line
    sed -i "s|^introducer_furl:.*$|introducer_furl: $furl|" "$MANIFEST_FILE"
  else
    # Add new line (after network section)
    local network_end=$(grep -n "^network:" "$MANIFEST_FILE" | cut -d: -f1)
    if [ -n "$network_end" ]; then
      # Find the next top-level section after network
      local next_section=$(tail -n +$((network_end + 1)) "$MANIFEST_FILE" | grep -n "^[a-zA-Z]" | head -n 1 | cut -d: -f1)
      if [ -n "$next_section" ]; then
        local insert_line=$((network_end + next_section - 1))
        sed -i "${insert_line}i\\introducer_furl: $furl" "$MANIFEST_FILE"
      else
        # If no next section, add to end of file
        echo "introducer_furl: $furl" >> "$MANIFEST_FILE"
      fi
    else
      # If no network section, add to beginning of file
      sed -i "1i\\introducer_furl: $furl" "$MANIFEST_FILE"
    fi
  fi
  
  log "Manifest updated with FURL: $furl"
  return 0
}

# Extract FURL from manifest
get_manifest_furl() {
  if [ ! -f "$MANIFEST_FILE" ]; then
    error "Manifest file not found: $MANIFEST_FILE"
    return 1
  fi
  
  local furl
  furl=$(grep -oP "^introducer_furl:\s*\K.*" "$MANIFEST_FILE")
  if [ -z "$furl" ] || [ "$furl" = "null" ]; then
    error "No introducer FURL found in manifest"
    return 1
  fi
  
  echo "$furl"
  return 0
}

# Update a Tahoe node's configuration with FURL
update_node_furl() {
  local node_type="$1"
  local furl="$2"
  local node_dir=""
  
  case "$node_type" in
    "client")
      node_dir="$CLIENT_DIR"
      ;;
    "storage")
      node_dir="$STORAGE_DIR"
      ;;
    *)
      error "Invalid node type: $node_type"
      return 1
      ;;
  esac
  
  if [ ! -d "$node_dir" ]; then
    error "$node_type directory not found: $node_dir"
    return 1
  }
  
  local tahoe_cfg="$node_dir/tahoe.cfg"
  if [ ! -f "$tahoe_cfg" ]; then
    error "$node_type configuration not found: $tahoe_cfg"
    return 1
  }
  
  log "Updating $node_type with introducer FURL: $furl"
  
  # Check if there's a section for introducers
  if grep -q "^\[client\]" "$tahoe_cfg"; then
    # Update or add introducer.furl line in the client section
    if grep -q "introducer.furl" "$tahoe_cfg"; then
      sed -i "/^introducer.furl/c\\introducer.furl = $furl" "$tahoe_cfg"
    else
      # Find the end of client section
      local client_line=$(grep -n "^\[client\]" "$tahoe_cfg" | cut -d: -f1)
      local next_section=$(tail -n +$((client_line + 1)) "$tahoe_cfg" | grep -n "^\[" | head -n 1 | cut -d: -f1)
      if [ -n "$next_section" ]; then
        local insert_line=$((client_line + next_section - 1))
        sed -i "${insert_line}i\\introducer.furl = $furl" "$tahoe_cfg"
      else
        # If no next section, add to end of file
        echo "introducer.furl = $furl" >> "$tahoe_cfg"
      fi
    fi
  else
    # Add client section if it doesn't exist
    cat >> "$tahoe_cfg" << EOF

[client]
introducer.furl = $furl
EOF
  fi
  
  # Save the FURL to cache
  echo "$furl" > "$FURL_CACHE_FILE"
  
  log "Updated $node_type configuration with introducer FURL"
  return 0
}

# Publish FURL from introducer
publish_introducer_furl() {
  log "Publishing introducer FURL from node $NODE_NAME"
  
  local furl=$(extract_introducer_furl)
  if [ -z "$furl" ]; then
    error "Could not extract introducer FURL"
    return 1
  fi
  
  # Cache the FURL locally
  echo "$furl" > "$FURL_CACHE_FILE"
  
  # Update the manifest
  if update_manifest_furl "$furl"; then
    log "Successfully published introducer FURL to manifest"
    
    # Check if we need to push the manifest to the repo
    if [ -x "$(command -v git)" ] && [ -d "$(dirname "$MANIFEST_FILE")/.git" ]; then
      log "Committing and pushing manifest changes to repository"
      (
        cd "$(dirname "$MANIFEST_FILE")"
        git add "$(basename "$MANIFEST_FILE")"
        git commit -m "Update introducer FURL for node $NODE_NAME" || true
        git push || log "Warning: Failed to push manifest changes to repository"
      )
    fi
    
    return 0
  else
    error "Failed to publish introducer FURL to manifest"
    return 1
  fi
}

# Synchronize FURL from manifest to client/storage nodes
sync_furl_from_manifest() {
  log "Synchronizing introducer FURL from manifest for node $NODE_NAME"
  
  local furl=$(get_manifest_furl)
  if [ -z "$furl" ]; then
    error "Could not get introducer FURL from manifest"
    return 1
  fi
  
  # Check if we have a cached FURL and it's the same
  if [ -f "$FURL_CACHE_FILE" ]; then
    local cached_furl=$(cat "$FURL_CACHE_FILE")
    if [ "$cached_furl" = "$furl" ]; then
      log "Cached FURL matches manifest FURL. No update needed."
      return 0
    fi
  fi
  
  # Update nodes based on roles
  local update_success=0
  
  if has_role "tahoe_client"; then
    log "Updating client node with introducer FURL"
    if update_node_furl "client" "$furl"; then
      update_success=1
    fi
  fi
  
  if has_role "tahoe_storage"; then
    log "Updating storage node with introducer FURL"
    if update_node_furl "storage" "$furl"; then
      update_success=1
    fi
  fi
  
  if [ $update_success -eq 1 ]; then
    log "Successfully synchronized introducer FURL to node(s)"
    return 0
  else
    error "Failed to synchronize introducer FURL to any node"
    return 1
  fi
}

# Main function to synchronize FURL based on node role
sync_introducer_furl() {
  log "Starting introducer FURL synchronization for node $NODE_NAME"
  
  # Determine what action to take based on node roles
  if has_role "tahoe_introducer"; then
    log "This is an introducer node. Publishing FURL to manifest."
    publish_introducer_furl
  elif has_role "tahoe_client" || has_role "tahoe_storage"; then
    log "This is a client or storage node. Syncing FURL from manifest."
    sync_furl_from_manifest
  else
    log "This node has no Tahoe-LAFS roles. Skipping FURL synchronization."
    return 0
  fi
}

# Execute FURL synchronization
sync_introducer_furl
exit $?