#!/bin/bash

set -e

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root. Try 'sudo $0'"
   exit 1
fi

# Install dependencies
apt-get update
apt-get install -y python3-pip python3-dev build-essential libffi-dev libssl-dev

# Install Tahoe-LAFS
pip3 install tahoe-lafs

echo "Tahoe-LAFS installation complete!"
