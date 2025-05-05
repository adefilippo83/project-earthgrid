#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${GREEN}$(date -u +"%Y-%m-%dT%H:%M:%SZ") [TEST] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$(date -u +"%Y-%m-%dT%H:%M:%SZ") [WARNING] $1${NC}"
}

print_error() {
    echo -e "${RED}$(date -u +"%Y-%m-%dT%H:%M:%SZ") [ERROR] $1${NC}"
}

# Check for Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

print_step "Building Earthgrid Tinc container for testing..."
docker build -t earthgrid/tinc:test ./earthgrid-tinc

print_step "Creating test GPG key..."
GPG_HOME="$(pwd)/test-gpg"
mkdir -p "$GPG_HOME" ./test-secrets

# Generate a temporary GPG key for testing
cat > /tmp/gpg-gen.batch << EOF
Key-Type: RSA
Key-Length: 2048
Name-Real: Test Node
Name-Email: test@example.com
Expire-Date: 0
%no-protection
%commit
EOF

# Use a temporary GNUPGHOME to avoid conflicts with user's keyring
GNUPGHOME="$GPG_HOME" gpg --batch --generate-key /tmp/gpg-gen.batch

# Get the key ID
GPG_KEY_ID=$(GNUPGHOME="$GPG_HOME" gpg --list-keys --with-colons test@example.com | grep -m 1 "^pub" | cut -d: -f5)
print_step "Generated test GPG key with ID: $GPG_KEY_ID"

# Export the private key for the container
GNUPGHOME="$GPG_HOME" gpg --armor --export-secret-keys "$GPG_KEY_ID" > ./test-secrets/gpg_private_key.asc
chmod 600 ./test-secrets/gpg_private_key.asc

print_step "Setting up test manifest..."
mkdir -p ./test-data/manifest-repo/manifest ./test-data/manifest

# Create a simple test manifest
cat > ./test-data/manifest-repo/manifest/manifest.yaml << EOF
---
network:
  name: earthgrid-test
  version: 2.0.0
  domain: test.grid.earth
  vpn_network: 10.200.0.0/16

nodes:
  - name: test-node
    internal_ip: 10.200.1.1
    public_ip: auto
    gpg_key_id: $GPG_KEY_ID
    region: test-region
    status: active
    storage_contribution: 10GB
    storage_allocation: 3GB
    is_publicly_accessible: true
EOF

print_step "Creating test environment..."
cat > ./.env.test << EOF
NODE_NAME=test-node
INTERNAL_VPN_IP=10.200.1.1
PUBLIC_IP=127.0.0.1
GPG_KEY_ID=$GPG_KEY_ID
GITHUB_REPO=test/repo
GITHUB_BRANCH=main
MANIFEST_FILENAME=manifest.yaml
ENABLE_AUTO_DISCOVERY=false
TEST_MODE=true
EOF

print_step "Creating local directories..."
mkdir -p ./test-data/tinc ./test-data/logs

print_step "Running container in test mode..."
docker run --name earthgrid-tinc-test --cap-add=NET_ADMIN \
  --env-file ./.env.test \
  -v "$(pwd)/test-data/tinc:/etc/tinc" \
  -v "$GPG_HOME:/root/.gnupg" \
  -v "$(pwd)/test-data/logs:/var/log/earthgrid" \
  -v "$(pwd)/test-data/manifest-repo:/var/lib/earthgrid/manifest-repo" \
  -v "$(pwd)/test-data/manifest:/var/lib/earthgrid/manifest" \
  -v "$(pwd)/test-secrets/gpg_private_key.asc:/run/secrets/gpg_private_key" \
  --entrypoint /bin/bash \
  earthgrid/tinc:test \
  -c "set -e; chmod +x /app/scripts/*.sh; /app/scripts/setup-tinc.sh && /app/scripts/sync-manifest.sh && echo 'Test completed successfully!'"

print_step "Verifying test results..."
docker cp earthgrid-tinc-test:/etc/tinc/earthgrid/tinc.conf ./test-data/tinc.conf
docker cp earthgrid-tinc-test:/etc/tinc/earthgrid/hosts/test-node ./test-data/test-node-host

echo "--- tinc.conf ---"
cat ./test-data/tinc.conf

echo "--- test-node host file ---"
cat ./test-data/test-node-host

if ! grep -q "Name = test-node" ./test-data/tinc.conf; then
  print_error "tinc.conf does not contain correct node name"
  exit 1
fi

if ! grep -q "Subnet = 10.200.1.1/32" ./test-data/test-node-host; then
  print_error "Host file does not contain correct subnet"
  exit 1
fi

print_step "Container tests passed successfully!"

# Cleanup
print_step "Cleaning up test environment..."
docker rm -f earthgrid-tinc-test

# Ask if the user wants to keep the test files
read -p "Do you want to keep the test files? (y/n): " KEEP_FILES
if [[ "$KEEP_FILES" != "y" && "$KEEP_FILES" != "Y" ]]; then
  rm -rf ./test-data ./test-secrets ./.env.test "$GPG_HOME"
  print_step "Test files removed."
else
  print_step "Test files kept for inspection at ./test-data and ./test-secrets"
fi

print_step "All tests completed successfully!"