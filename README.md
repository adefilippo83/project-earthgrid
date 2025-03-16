# Project Earthgrid - tinc VPN Configuration

This repository contains centralized configuration management for a tinc VPN mesh network, primarily designed for Raspberry Pi devices behind NAT without requiring port forwarding.

## Features

- Centralized management of tinc VPN configuration
- Automatic NAT traversal setup (no port forwarding required)
- Git-based version control for configuration and public keys
- Support for full mesh network topology
- Designed for Raspberry Pi devices
- Hostname-based configuration for easier maintenance
- Automated configuration updates via systemd timer

## Repository Structure

```
.
├── tinc/                        # tinc VPN configuration directory
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
│   └── docs/
│       └── PR-PROCESS.md        # Documentation for the PR process
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

## Adding a New Node

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

## Automated Configuration Updates

The repository includes systemd service and timer files to automatically update your node's configuration from the repository. This ensures your node stays in sync with network changes without manual intervention.

To set up automated updates:

1. Copy the systemd files to your systemd directory:
   ```bash
   sudo cp /opt/project-earthgrid/tinc/tinc-autoupdate.service /etc/systemd/system/
   sudo cp /opt/project-earthgrid/tinc/tinc-autoupdate.timer /etc/systemd/system/
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

To check the status of the automated update service:
```bash
sudo systemctl status tinc-autoupdate.timer
sudo systemctl list-timers --all
```

To modify the update frequency, edit the timer file and change the `OnUnitActiveSec` value:
```bash
sudo nano /etc/systemd/system/tinc-autoupdate.timer
# Change OnUnitActiveSec=30min to your desired interval
# Then reload and restart:
sudo systemctl daemon-reload
sudo systemctl restart tinc-autoupdate.timer
```

## Adding a Public Node

If you have access to a server with a public hostname (like a VPS), add it to your nodes:

```yaml
nodes:
  - name: publicnode
    vpn_ip: 172.16.0.254
    hostname: publicnode.example.com
    is_publicly_accessible: true
```

This will help nodes behind NAT to connect reliably.

## Troubleshooting

### Checking VPN Status

On any node:

```bash
sudo systemctl status tinc@pi-net
sudo journalctl -u tinc@pi-net
sudo tincd -n pi-net -d5    # For debug output
```

### Testing Connectivity

From any node, ping another node using its VPN IP:

```bash
ping 172.16.0.2  # Replace with another node's VPN IP
```

Or using hostname (if configured in /etc/hosts or DNS):

```bash
ping node2.vpn   # If you've set up hostname resolution
```

### Common Issues

1. **Nodes can't connect**: Ensure all nodes have updated host files with the latest public keys.
2. **Hostname resolution failures**: Make sure all hostnames used in configuration are resolvable or consider setting up an internal DNS.
3. **Connection timeouts**: NAT traversal might be failing; consider adding a public node.
4. **Git errors**: Check your git credentials and repository access.

## Security Considerations

- This setup doesn't use port forwarding, which improves security
- All traffic between nodes is encrypted
- Using hostnames instead of hardcoded IPs allows for more flexibility with dynamic IPs

## License

This project is licensed under the GPL License - see the LICENSE file for details.
