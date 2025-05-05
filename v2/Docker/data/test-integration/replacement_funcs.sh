#!/bin/bash
# Test replacements for validate-vpn-network.sh functions

# Replacement for the check_vpn_interface function
check_vpn_interface() {
  log "TEST MODE: Skipping actual VPN interface check"
  return 0
}

# Replacement for the check_connectivity function
check_connectivity() {
  log "TEST MODE: Skipping actual connectivity check"
  return 0
}