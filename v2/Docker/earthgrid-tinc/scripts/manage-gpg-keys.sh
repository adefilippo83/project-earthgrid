#!/bin/bash
set -e

# Log function
log() {
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") [GPG-MANAGER] $1"
}

print_usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  generate <name> <email>   Generate a new GPG key pair"
    echo "  export <key_id> [file]    Export public key to file or stdout"
    echo "  export-private <key_id> [file]  Export private key to file or stdout"
    echo "  import <file>             Import GPG key from file"
    echo "  list                      List available keys"
    echo "  delete <key_id>           Delete a key pair"
    echo ""
    echo "Options:"
    echo "  <name>      Real name for key generation"
    echo "  <email>     Email for key generation"
    echo "  <key_id>    GPG key ID"
    echo "  <file>      File path for import/export operations"
}

# Command: generate a new GPG key pair
generate_key() {
    if [ $# -lt 2 ]; then
        log "ERROR: Name and email are required for key generation"
        print_usage
        exit 1
    fi
    
    NAME="$1"
    EMAIL="$2"
    
    log "Generating new GPG key pair for $NAME <$EMAIL>..."
    
    # Create batch file for unattended key generation
    cat > /tmp/gpg-gen-key.batch << EOF
Key-Type: RSA
Key-Length: 4096
Name-Real: $NAME
Name-Email: $EMAIL
Expire-Date: 0
%no-protection
%commit
EOF
    
    # Generate key
    gpg --batch --generate-key /tmp/gpg-gen-key.batch
    
    # Get key ID and display
    KEY_ID=$(gpg --list-keys --with-colons "$EMAIL" | grep -m 1 "^pub" | cut -d: -f5)
    
    log "Key generation successful!"
    log "Key ID: $KEY_ID"
    log "You can use this ID in the manifest.yaml file and for Docker environment variables"
    
    # Clean up
    rm -f /tmp/gpg-gen-key.batch
}

# Command: export public key
export_key() {
    if [ $# -lt 1 ]; then
        log "ERROR: Key ID is required for export"
        print_usage
        exit 1
    fi
    
    KEY_ID="$1"
    OUTPUT_FILE="$2"
    
    log "Exporting public key $KEY_ID..."
    
    if [ -z "$OUTPUT_FILE" ]; then
        # Export to stdout
        gpg --armor --export "$KEY_ID"
    else
        # Export to file
        gpg --armor --export "$KEY_ID" > "$OUTPUT_FILE"
        log "Public key exported to $OUTPUT_FILE"
    fi
}

# Command: export private key
export_private_key() {
    if [ $# -lt 1 ]; then
        log "ERROR: Key ID is required for private key export"
        print_usage
        exit 1
    fi
    
    KEY_ID="$1"
    OUTPUT_FILE="$2"
    
    log "Exporting private key $KEY_ID..."
    log "CAUTION: This exports your private key. Keep it secure!"
    
    if [ -z "$OUTPUT_FILE" ]; then
        # Export to stdout
        gpg --armor --export-secret-keys "$KEY_ID"
    else
        # Export to file
        gpg --armor --export-secret-keys "$KEY_ID" > "$OUTPUT_FILE"
        chmod 600 "$OUTPUT_FILE"
        log "Private key exported to $OUTPUT_FILE"
    fi
}

# Command: import key
import_key() {
    if [ $# -lt 1 ]; then
        log "ERROR: File path is required for import"
        print_usage
        exit 1
    fi
    
    FILE="$1"
    
    if [ ! -f "$FILE" ]; then
        log "ERROR: File $FILE not found"
        exit 1
    fi
    
    log "Importing GPG key from $FILE..."
    gpg --batch --import "$FILE"
    log "Key import successful!"
}

# Command: list keys
list_keys() {
    log "Listing available GPG keys..."
    gpg --list-keys
}

# Command: delete key
delete_key() {
    if [ $# -lt 1 ]; then
        log "ERROR: Key ID is required for deletion"
        print_usage
        exit 1
    fi
    
    KEY_ID="$1"
    
    log "Deleting GPG key $KEY_ID..."
    log "WARNING: This will delete both public and private keys!"
    
    # Delete secret key first, then public key
    gpg --batch --yes --delete-secret-keys "$KEY_ID"
    gpg --batch --yes --delete-keys "$KEY_ID"
    
    log "Key deletion successful!"
}

# Main command router
case "$1" in
    generate)
        shift
        generate_key "$@"
        ;;
    export)
        shift
        export_key "$@"
        ;;
    export-private)
        shift
        export_private_key "$@"
        ;;
    import)
        shift
        import_key "$@"
        ;;
    list)
        list_keys
        ;;
    delete)
        shift
        delete_key "$@"
        ;;
    *)
        print_usage
        exit 1
        ;;
esac