#!/bin/bash
set -e

# Log function
log() {
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [ENTRYPOINT] $1"
}

# Verify essential environment variables
log "Starting Earthgrid-Tinc node setup..."

if [ -z "$NODE_NAME" ]; then
    log "ERROR: NODE_NAME not defined"
    exit 1
fi

if [ -z "$INTERNAL_VPN_IP" ]; then
    log "ERROR: INTERNAL_VPN_IP not defined"
    exit 1
fi

if [ -z "$GITHUB_REPO" ]; then
    log "ERROR: GITHUB_REPO not defined. Required format: username/repository"
    exit 1
fi

if [ -z "$GPG_KEY_ID" ]; then
    log "ERROR: GPG_KEY_ID not defined. You must provide an existing GPG key ID"
    exit 1
fi

# Verify the presence of GPG key
log "Verifying GPG key with ID: $GPG_KEY_ID"

# Fix permissions on gpg home
if [ -d "/root/.gnupg" ]; then
    chmod 700 /root/.gnupg
    if [ -f "/root/.gnupg/gpg.conf" ]; then
        chmod 600 /root/.gnupg/gpg.conf
    fi
    if [ -f "/root/.gnupg/private-keys-v1.d" ]; then
        chmod 700 /root/.gnupg/private-keys-v1.d
    fi
fi

if ! gpg --list-keys "$GPG_KEY_ID" > /dev/null 2>&1; then
    # If key provided as environment variable
    if [ ! -z "$GPG_PRIVATE_KEY" ]; then
        log "Importing GPG key from environment variable..."
        echo "$GPG_PRIVATE_KEY" | gpg --batch --import
    # If key provided as Docker secret
    elif [ -f "/run/secrets/gpg_private_key" ]; then
        log "Importing GPG key from mounted file (Docker secret)..."
        gpg --batch --import /run/secrets/gpg_private_key
    # If the .gnupg directory is mounted as a volume
    elif [ -d "/root/.gnupg" ] && [ "$(ls -A /root/.gnupg)" ]; then
        log "Using existing GPG keyring mounted as volume..."
    else
        log "ERROR: GPG key $GPG_KEY_ID not found and no private key provided."
        log "You must provide an existing GPG key through one of these methods:"
        log "1. Docker secret (gpg_private_key)"
        log "2. Environment variable GPG_PRIVATE_KEY"
        log "3. Mounted volume with existing GPG keyring"
        exit 1
    fi
    
    # Verify that the key is now available
    if ! gpg --list-keys "$GPG_KEY_ID" > /dev/null 2>&1; then
        log "ERROR: Could not import GPG key $GPG_KEY_ID"
        exit 1
    fi
fi

# Check for private key
if ! gpg --list-secret-keys "$GPG_KEY_ID" > /dev/null 2>&1; then
    log "ERROR: Private key for $GPG_KEY_ID is not available"
    exit 1
fi

log "GPG key $GPG_KEY_ID verified successfully"

# Initial setup
log "Running initial Tinc setup..."
/app/scripts/setup-tinc.sh

# Configure periodic synchronization
if [ "${ENABLE_AUTO_DISCOVERY:-true}" = "true" ] || [ "${ENABLE_AUTO_DISCOVERY:-true}" = "1" ]; then
    log "Setting up automatic synchronization..."
    SYNC_INTERVAL=${SYNC_INTERVAL:-3600}
    SYNC_CRON="*/$(($SYNC_INTERVAL / 60)) * * * * /app/scripts/sync-manifest.sh >> /var/log/earthgrid/sync-manifest.log 2>&1"
    echo "$SYNC_CRON" > /etc/cron.d/sync-manifest
    chmod 0644 /etc/cron.d/sync-manifest
fi

# Initial manifest synchronization
log "Performing initial manifest synchronization..."
/app/scripts/sync-manifest.sh

# Enable the tincd program in supervisor
log "Enabling Tinc VPN daemon..."
supervisorctl start tincd

log "Entrypoint script completed successfully"
