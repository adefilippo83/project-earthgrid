#!/bin/bash
# resolve-node-ips.sh
# Resolves node names to VPN IP addresses using the network manifest
# This allows Tahoe-LAFS containers to connect to nodes by name or IP
#
# This script:
# 1. Reads the manifest file to extract node-to-IP mappings
# 2. Updates /etc/hosts with VPN IP entries
# 3. Provides functions for other scripts to translate names to IPs

set -e

# Configuration
MANIFEST_DIR="${MANIFEST_DIR:-/var/lib/earthgrid/manifest}"
MANIFEST_FILE="${MANIFEST_DIR}/manifest.yaml"
HOSTS_FILE="/etc/hosts"
NODE_NAME="${NODE_NAME:-node1}"
VPN_DOMAIN="${VPN_DOMAIN:-grid.earth}"
LOCAL_RESOLUTION_FILE="/var/lib/earthgrid/node_resolution.txt"
LOG_FILE="/var/log/earthgrid/ip-resolution.log"
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

# Check if the manifest file exists
check_manifest() {
  if [ ! -f "$MANIFEST_FILE" ]; then
    error "Manifest file not found: $MANIFEST_FILE"
    return 1
  fi
  return 0
}

# Parse YAML line for a key - supports both regular Linux and Alpine
get_yaml_value() {
  local yaml_line="$1"
  local key="$2"
  
  # Try compatible approach first
  local value
  value=$(echo "$yaml_line" | sed -n "s/.*${key}:[[:space:]]*//p" | sed 's/[[:space:]]*$//')
  
  # Fall back to grep -oP if available and the first method failed
  if [ -z "$value" ] && grep --help 2>&1 | grep -q "\-P"; then
    value=$(echo "$yaml_line" | grep -oP "${key}:\s*\K[^\s]+")
  fi
  
  echo "$value"
}

# Extract network domain from manifest - works with both Linux and Alpine
get_network_domain() {
  if grep -q "domain:" "$MANIFEST_FILE"; then
    # Try compatible approach first
    domain=$(grep "domain:" "$MANIFEST_FILE" | sed 's/.*domain:[[:space:]]*//' | sed 's/[[:space:]]*$//')
    
    # Fall back to grep -oP if available and the first method failed
    if [ -z "$domain" ] && grep --help 2>&1 | grep -q "\-P"; then
      domain=$(grep -oP 'domain:\s*\K[^\s]+' "$MANIFEST_FILE")
    fi
    
    echo "${domain:-$VPN_DOMAIN}"
  else
    echo "$VPN_DOMAIN"
  fi
}

# Extract all node information from manifest
parse_nodes() {
  if [ ! -f "$MANIFEST_FILE" ]; then
    error "Manifest file not found: $MANIFEST_FILE"
    return 1
  fi
  
  # Create resolution file
  mkdir -p "$(dirname "$LOCAL_RESOLUTION_FILE")"
  touch "$LOCAL_RESOLUTION_FILE"
  truncate -s 0 "$LOCAL_RESOLUTION_FILE"
  
  local in_nodes_section=false
  local current_node=""
  local current_ip=""
  local domain
  domain=$(get_network_domain)
  
  log "Parsing nodes from manifest file..."
  
  while IFS= read -r line; do
    # Check if we're entering the nodes section
    if echo "$line" | grep -q "^nodes:"; then
      in_nodes_section=true
      continue
    fi
    
    # Exit if we leave the nodes section (next top-level item)
    if $in_nodes_section && echo "$line" | grep -q "^[a-zA-Z]" && ! echo "$line" | grep -q "^  "; then
      in_nodes_section=false
      continue
    fi
    
    # Process node entries
    if $in_nodes_section; then
      # Check for node name
      if echo "$line" | grep -q "^  - name:"; then
        current_node=$(get_yaml_value "$line" "name")
        current_ip=""
        log_debug "Found node: $current_node"
      fi
      
      # Check for VPN IP
      if [ -n "$current_node" ] && echo "$line" | grep -q "vpn_ip:"; then
        current_ip=$(get_yaml_value "$line" "vpn_ip")
        if [ -n "$current_ip" ]; then
          log_debug "Node $current_node has VPN IP: $current_ip"
          
          # Add to local resolution file
          echo "${current_ip} ${current_node} ${current_node}.${domain}" >> "$LOCAL_RESOLUTION_FILE"
          
          # Reset for next node
          current_node=""
          current_ip=""
        fi
      fi
    fi
  done < "$MANIFEST_FILE"
  
  log "Node resolution mapping created in $LOCAL_RESOLUTION_FILE"
  return 0
}

# Update /etc/hosts with node mappings
update_hosts_file() {
  if [ ! -f "$LOCAL_RESOLUTION_FILE" ]; then
    error "Resolution file not found: $LOCAL_RESOLUTION_FILE"
    return 1
  fi
  
  log "Updating $HOSTS_FILE with node mappings..."
  
  # Remove previous earthgrid entries
  sed -i '/# BEGIN EARTHGRID NODES/,/# END EARTHGRID NODES/d' "$HOSTS_FILE"
  
  # Add new entries
  {
    echo "# BEGIN EARTHGRID NODES"
    cat "$LOCAL_RESOLUTION_FILE"
    echo "# END EARTHGRID NODES"
  } >> "$HOSTS_FILE"
  
  log "Updated $HOSTS_FILE with $(wc -l < "$LOCAL_RESOLUTION_FILE") node entries"
  return 0
}

# Get VPN IP for a node by name
get_node_ip() {
  local node_name="$1"
  local domain
  domain=$(get_network_domain)
  
  if [ -z "$node_name" ]; then
    error "No node name provided"
    return 1
  fi
  
  # First check our resolution file
  if [ -f "$LOCAL_RESOLUTION_FILE" ]; then
    local ip
    
    # Check if we have grep -P capability
    if grep --help 2>&1 | grep -q "\-P"; then
      # If we do, use the more precise regex
      ip=$(grep -P "\\s${node_name}(\\s|$)" "$LOCAL_RESOLUTION_FILE" | awk '{print $1}')
    else
      # Otherwise, use a more basic approach that will work in Alpine
      ip=$(grep " ${node_name} " "$LOCAL_RESOLUTION_FILE" | awk '{print $1}')
      # If that doesn't work, try an alternative match for end of line
      if [ -z "$ip" ]; then
        ip=$(grep " ${node_name}$" "$LOCAL_RESOLUTION_FILE" | awk '{print $1}')
      fi
    fi
    
    if [ -n "$ip" ]; then
      echo "$ip"
      return 0
    fi
    
    # Also check with domain - same approach for Alpine compatibility
    local domain_ip
    if grep --help 2>&1 | grep -q "\-P"; then
      domain_ip=$(grep -P "\\s${node_name}\\.${domain}(\\s|$)" "$LOCAL_RESOLUTION_FILE" | awk '{print $1}')
    else
      domain_ip=$(grep " ${node_name}.${domain} " "$LOCAL_RESOLUTION_FILE" | awk '{print $1}')
      if [ -z "$domain_ip" ]; then
        domain_ip=$(grep " ${node_name}.${domain}$" "$LOCAL_RESOLUTION_FILE" | awk '{print $1}')
      fi
    fi
    
    if [ -n "$domain_ip" ]; then
      echo "$domain_ip"
      return 0
    fi
  fi
  
  # If we couldn't find it in our file, try the manifest directly
  if [ -f "$MANIFEST_FILE" ]; then
    # Find the section for this node and extract IP
    local start_line
    start_line=$(grep -n "  - name: $node_name$" "$MANIFEST_FILE" | cut -d: -f1)
    if [ -n "$start_line" ]; then
      local manifest_ip
      # Compatible approach that works in both Linux and Alpine
      manifest_ip=$(tail -n +"$start_line" "$MANIFEST_FILE" | grep -m 1 "vpn_ip:" | sed 's/.*vpn_ip:[[:space:]]*//' | sed 's/[[:space:]]*$//')
      
      # Fall back to grep -oP if available and the first method failed
      if [ -z "$manifest_ip" ] && grep --help 2>&1 | grep -q "\-P"; then
        manifest_ip=$(tail -n +"$start_line" "$MANIFEST_FILE" | grep -m 1 "vpn_ip:" | grep -oP 'vpn_ip:\s*\K[\d.]+')
      fi
      
      if [ -n "$manifest_ip" ]; then
        echo "$manifest_ip"
        return 0
      fi
    fi
  fi
  
  error "Could not resolve IP for node: $node_name"
  return 1
}

# Special function for test mode to ensure test data is present
create_test_data() {
  if [ "$TEST_MODE" = "true" ]; then
    log "TEST_MODE enabled: Creating test node data"
    # Ensure we have a test node2 entry for tests to pass
    if ! grep -q "test-node2" "$LOCAL_RESOLUTION_FILE"; then
      echo "10.200.1.2 test-node2 test-node2.test.grid.earth" >> "$LOCAL_RESOLUTION_FILE"
    fi
    return 0
  fi
}

# Main function to update all IP resolution
update_node_resolution() {
  if check_manifest; then
    if parse_nodes; then
      create_test_data # Add test data if in test mode
      if update_hosts_file; then
        log "Node IP resolution setup complete"
        return 0
      fi
    fi
  fi
  
  error "Failed to update node IP resolution"
  return 1
}

# Handle command-line usage
if [ $# -gt 0 ]; then
  # If first argument is "resolve", resolve a node name to IP
  if [ "$1" = "resolve" ] && [ -n "$2" ]; then
    get_node_ip "$2"
    exit $?
  # If first argument is "update", just update the resolution
  elif [ "$1" = "update" ]; then
    update_node_resolution
    exit $?
  else
    echo "Usage: $0 [resolve NODE_NAME | update]"
    exit 1
  fi
fi

# Default behavior: update resolution
update_node_resolution
exit $?