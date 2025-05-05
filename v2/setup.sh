#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${GREEN}$(date -u +"%Y-%m-%dT%H:%M:%SZ") [SETUP] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$(date -u +"%Y-%m-%dT%H:%M:%SZ") [WARNING] $1${NC}"
}

print_error() {
    echo -e "${RED}$(date -u +"%Y-%m-%dT%H:%M:%SZ") [ERROR] $1${NC}"
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    print_warning "This script is not running as root. Some operations might fail."
    print_warning "Consider running with sudo if you encounter permission errors."
fi

# Print banner
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║             Project Earthgrid v2 Setup                ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check prerequisites
print_step "Checking prerequisites..."

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Check GPG
if ! command -v gpg &> /dev/null; then
    print_error "GPG is not installed. Please install GnuPG first."
    exit 1
fi

print_step "All prerequisites are met."

# Create necessary directories
print_step "Creating directories..."
mkdir -p Docker/data/tinc Docker/data/gnupg Docker/data/logs Docker/secrets

# Environment setup
print_step "Setting up environment..."

# Node name
read -p "Enter node name (default: auto-generated): " NODE_NAME
if [ -z "$NODE_NAME" ]; then
    NODE_NAME="node-$(hostname | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-' | head -c 8)"
    print_warning "Using auto-generated node name: $NODE_NAME"
fi

# Check if GPG key already exists
GPG_KEYS=$(gpg --list-keys --with-colons | grep -c '^pub:')
if [ "$GPG_KEYS" -gt 0 ]; then
    print_step "Found existing GPG keys. Please select one or create a new key."
    gpg --list-keys
    
    read -p "Use existing key? (y/n): " USE_EXISTING
    if [[ "$USE_EXISTING" =~ ^[Yy]$ ]]; then
        read -p "Enter GPG key ID to use: " GPG_KEY_ID
    else
        print_step "Will create a new GPG key."
        GPG_KEY_ID=""
    fi
else
    print_step "No existing GPG keys found. Will create a new one."
    GPG_KEY_ID=""
fi

# Generate new GPG key if needed
if [ -z "$GPG_KEY_ID" ]; then
    print_step "Generating new GPG key pair..."
    read -p "Enter your real name: " GPG_NAME
    read -p "Enter your email: " GPG_EMAIL
    
    # Create batch file for unattended key generation
    cat > /tmp/gpg-gen-key.batch << EOF
Key-Type: RSA
Key-Length: 4096
Name-Real: $GPG_NAME
Name-Email: $GPG_EMAIL
Expire-Date: 0
%no-protection
%commit
EOF
    
    # Generate key
    gpg --batch --generate-key /tmp/gpg-gen-key.batch
    
    # Get key ID
    GPG_KEY_ID=$(gpg --list-keys --with-colons "$GPG_EMAIL" | grep -m 1 "^pub" | cut -d: -f5)
    
    print_step "GPG key generated successfully!"
    print_step "Key ID: $GPG_KEY_ID"
    
    # Clean up
    rm -f /tmp/gpg-gen-key.batch
fi

# Export GPG key
print_step "Exporting GPG private key for Docker secret..."
gpg --armor --export-secret-keys "$GPG_KEY_ID" > Docker/secrets/gpg_private_key.asc
chmod 600 Docker/secrets/gpg_private_key.asc

# VPN IP
read -p "Enter internal VPN IP (default: 10.100.1.1): " INTERNAL_VPN_IP
INTERNAL_VPN_IP=${INTERNAL_VPN_IP:-10.100.1.1}

# GitHub repo
read -p "Enter GitHub repository for manifest (default: earthgrid/config): " GITHUB_REPO
GITHUB_REPO=${GITHUB_REPO:-earthgrid/config}

# Create .env file
print_step "Creating .env file..."
cat > Docker/.env << EOF
NODE_NAME=$NODE_NAME
INTERNAL_VPN_IP=$INTERNAL_VPN_IP
PUBLIC_IP=auto
GPG_KEY_ID=$GPG_KEY_ID
GITHUB_REPO=$GITHUB_REPO
GITHUB_BRANCH=main
MANIFEST_FILENAME=manifest.yaml
ENABLE_AUTO_DISCOVERY=true
SYNC_INTERVAL=3600
GPG_KEY_FILE=./secrets/gpg_private_key.asc
EOF

print_step "Environment file created successfully."

# Build and start containers
print_step "Building and starting containers..."
cd Docker
docker-compose build
docker-compose up -d

# Provide instructions for next steps
print_step "Earthgrid node setup completed successfully!"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Add your node to the manifest.yaml file in the GitHub repository:"
echo "   - Name: $NODE_NAME"
echo "   - Internal IP: $INTERNAL_VPN_IP"
echo "   - GPG Key ID: $GPG_KEY_ID"
echo ""
echo "2. Submit a pull request to the repository"
echo "3. Wait for approval from a network administrator"
echo ""
echo -e "${YELLOW}For more information:${NC}"
echo "- See the documentation in the 'docs' directory"
echo "- Check container logs with: docker logs earthgrid-tinc"
echo "- Monitor node status with: docker exec earthgrid-tinc tinc -n earthgrid dump nodes"
echo ""
echo -e "${GREEN}Thank you for joining Project Earthgrid!${NC}"