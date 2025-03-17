# Project Earthgrid - Tinc VPN & Tahoe-LAFS Distributed Storage

This repository contains centralized configuration management for a Tinc VPN mesh network with Tahoe-LAFS distributed storage capabilities, primarily designed for Raspberry Pi devices behind NAT without requiring port forwarding.

## Features

### VPN Features
- Centralized management of Tinc VPN configuration
- Automatic NAT traversal setup (no port forwarding required)
- Git-based version control for configuration and public keys
- Support for full mesh network topology
- Designed for Raspberry Pi devices
- Hostname-based configuration for easier maintenance
- Automated configuration updates via systemd timer

### Storage Features
- Secure, distributed storage across all nodes using Tahoe-LAFS
- End-to-end encryption of all stored data
- Redundant storage with configurable replication factors
- Self-healing when nodes leave or rejoin the network
- Web interface for easy file access
- No single point of failure
- Automatic integration with the VPN for security

## Repository Structure

```
.
├── tinc/                        # Tinc VPN configuration directory
│   ├── config/                  # Configuration templates
│   │   ├── tinc.conf.template   # Base tinc.conf template
│   │   ├── tinc-up.template     # Base tinc-up script template
│   │   └── tinc-down.template   # Base tinc-down script template
│   ├── hosts/                   # Host files with public keys
│   │   ├── node1                # Public key for node1
│   │   ├── node2                # Public key for node2
│   │   └── node3                # Public key for node3
│   ├── scripts/
│   │   ├── setup-node.sh        # Script to set up a new node
│   │   ├── update-config.sh     # Script to update configuration on a node
│   │   ├── generate-keys.sh     # Script to generate keys for a new node
│   │   └── bootstrap.sh         # Bootstrap script for new nodes
│   ├── inventory/
│   │   └── nodes.yml            # Node inventory with IPs and details
│   ├── systemd/
│   │   ├── tinc-autoupdate.service # Systemd service for auto-updates
│   │   └── tinc-autoupdate.timer   # Systemd timer for auto-updates
│   └── docs/
│       └── PR-PROCESS.md        # Documentation for the PR process
├── tahoe/                       # Tahoe-LAFS configuration directory
│   ├── config/                  # Configuration templates
│   │   ├── introducer.cfg.template    # Template for introducer nodes
│   │   ├── storage.cfg.template       # Template for storage nodes
│   │   ├── client.cfg.template        # Template for client nodes
│   │   └── web.cfg.template           # Template for web gateway configuration
│   ├── scripts/
│   │   ├── install-tahoe.sh           # Script to install Tahoe-LAFS
│   │   ├── setup-tahoe-node.sh        # Script to set up a Tahoe node
│   │   ├── update-tahoe-config.sh     # Script to update Tahoe configuration
│   │   ├── bootstrap-tahoe-grid.sh    # Initialize the Tahoe grid (first-time setup)
│   │   └── add-storage-node.sh        # Add a new storage node to the grid
│   ├── systemd/
│   │   ├── tahoe-introducer.service   # Systemd service for the introducer
│   │   ├── tahoe-storage.service      # Systemd service for storage nodes
│   │   ├── tahoe-client.service       # Systemd service for client nodes
│   │   └── tahoe-web.service          # Systemd service for web gateway
│   ├── inventory/
│   │   └── tahoe-nodes.yml            # Tahoe node inventory with roles and details
│   └── docs/
│       └── TAHOE-USAGE.md             # Documentation on using the storage grid
└── .github/
    ├── workflows/
    │   └── validate-pr.yml      # PR validation workflow
    ├── scripts/
    │   └── validate_pr.py       # PR validation script
    └── pull_request_template.md # PR template
```

## Prerequisites

- Raspberry Pi devices with Raspberry Pi OS installed
- Internet access for all devices
- Git installed on all devices
- Basic understanding of Linux

## Tinc VPN Setup

### Adding a New Node

Follow these steps to add a new node to the VPN network:

1. Clone the repository to the new Raspberry Pi:
   ```bash
   sudo mkdir -p /opt
   sudo git clone https://github.com/adefilippo83/project-earthgrid.git /opt/project-earthgrid
   cd /opt/project-earthgrid
   ```

2. Create a new branch for your node:
   ```bash
   git checkout -b add-node-mynodename
   ```

3. Add your node details to the inventory file:
   ```bash
   # Edit the inventory file with your preferred editor
   sudo nano tinc/inventory/nodes.yml
   
   # Add your node's information in the format:
   # - name: mynodename
   #   vpn_ip: 172.16.0.X  # Choose an unused IP
   #   hostname: mynodename.example.com  # Use your node's hostname
   ```

4. Run the bootstrap script to configure your node:
   ```bash
   sudo tinc/scripts/bootstrap.sh mynodename
   ```

5. Commit your changes and push to the repository:
   ```bash
   git add tinc/inventory/nodes.yml tinc/hosts/mynodename
   git commit -m "Add new node: mynodename"
   git push origin add-node-mynodename
   ```

6. Create a pull request on GitHub from your branch to the main branch

7. Wait for the PR to be reviewed and approved by a network administrator

For more details on the PR process, see [tinc/docs/PR-PROCESS.md](tinc/docs/PR-PROCESS.md)

## Tahoe-LAFS Storage Setup

### Understanding Tahoe Roles

Each node in your network can have one or more of these roles:

1. **Introducer**: Acts as a discovery service helping nodes find each other (typically only need one)
2. **Storage**: Contributes storage space to the grid
3. **Client**: Allows access to read/write files on the grid
4. **Web**: Provides a web interface to browse and manage files

### Setting Up Tahoe-LAFS Grid

1. Define your Tahoe node roles in the inventory:
   ```bash
   sudo nano tahoe/inventory/tahoe-nodes.yml
   
   # Add Tahoe roles to your nodes:
   nodes:
     - name: node1
       tahoe_roles:
         - introducer
         - storage
         - client
         - web
       tahoe_storage_size: 50GB
       tahoe_web_port: 3456
     
     - name: node2
       tahoe_roles:
         - storage
       tahoe_storage_size: 100GB
   ```

2. Bootstrap the Tahoe-LAFS grid from your introducer node:
   ```bash
   sudo tahoe/scripts/bootstrap-tahoe-grid.sh
   ```

3. Verify the grid is working:
   ```bash
   # On any client node
   sudo -u tahoe tahoe create-alias grid
   sudo -u tahoe tahoe mkdir grid:test
   sudo -u tahoe echo "Hello Grid" > /tmp/test.txt
   sudo -u tahoe tahoe put /tmp/test.txt grid:test/hello.txt
   sudo -u tahoe tahoe get grid:test/hello.txt
   ```

### Adding Storage to an Existing Node

If you have an existing node in the VPN and want to add storage capabilities:

1. Update the Tahoe inventory file to include the node:
   ```bash
   sudo nano tahoe/inventory/tahoe-nodes.yml
   # Add the node with appropriate roles
   ```

2. Run the setup script on the node:
   ```bash
   sudo tahoe/scripts/setup-tahoe-node.sh mynodename
   ```

## Automated Configuration Updates

The repository includes systemd service and timer files to automatically update both VPN and storage configurations from the repository.

To set up automated updates:

1. Copy the systemd files to your systemd directory:
   ```bash
   sudo cp /opt/project-earthgrid/tinc/systemd/tinc-autoupdate.service /etc/systemd/system/
   sudo cp /opt/project-earthgrid/tinc/systemd/tinc-autoupdate.timer /etc/systemd/system/
   ```

2. Reload systemd to recognize the new files:
   ```bash
   sudo systemctl daemon-reload
   ```

3. Enable and start the timer:
   ```bash
   sudo systemctl enable tinc-autoupdate.timer
   sudo systemctl start tinc-autoupdate.timer
   ```

By default, the update service will run:
- 5 minutes after system boot
- Every 30 minutes thereafter

## Using the Distributed Storage

### Command Line Access

From any node with the client role:

```bash
# Create a new directory
sudo -u tahoe tahoe mkdir grid:mydirectory

# Upload a file
sudo -u tahoe tahoe put /path/to/local/file.txt grid:mydirectory/file.txt

# Download a file
sudo -u tahoe tahoe get grid:mydirectory/file.txt /path/to/local/destination.txt

# List contents of a directory
sudo -u tahoe tahoe ls grid:mydirectory/
```

### Web Interface Access

If you have nodes with the web role enabled:

1. Access the web interface at: `http://[node-vpn-ip]:3456/`
2. You can browse, upload, and download files through this interface
3. To access from outside the VPN, consider setting up a reverse proxy

## Storage Grid Health

To check the health of your storage grid:

```bash
# On any client node
sudo -u tahoe tahoe statistics gatherer-uri

# Check storage status of the grid
sudo -u tahoe tahoe status

# Check disk usage
sudo -u tahoe tahoe disk-usage
```

## Troubleshooting

### VPN Issues

On any node:

```bash
sudo systemctl status tinc@pi-net
sudo journalctl -u tinc@pi-net
sudo tincd -n pi-net -d5    # For debug output
```

### Storage Issues

On any node:

```bash
# Check Tahoe service status
sudo systemctl status tahoe-storage
sudo systemctl status tahoe-introducer
sudo systemctl status tahoe-client
sudo systemctl status tahoe-web

# View logs
sudo journalctl -u tahoe-storage
sudo journalctl -u tahoe-introducer

# Check connectivity to the introducer
sudo -u tahoe tahoe ping-introducer
```

### Common Issues

1. **Nodes can't connect**: Ensure all nodes have updated host files with the latest public keys.
2. **Storage nodes not visible**: Check if the introducer is running and nodes can connect to it.
3. **Cannot store/retrieve files**: Verify you have enough storage nodes online to satisfy the redundancy settings.
4. **Connection timeouts**: NAT traversal might be failing; consider adding a public node.

## Security Considerations

- This setup doesn't use port forwarding, which improves security
- All VPN traffic between nodes is encrypted
- All stored data is encrypted end-to-end with Tahoe-LAFS
- Multiple storage nodes provide redundancy against node failures

## License

This project is licensed under the GPL License - see the LICENSE file for details.
