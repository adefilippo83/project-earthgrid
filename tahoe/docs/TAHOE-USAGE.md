# Tahoe-LAFS Usage Guide

This document provides comprehensive information on using the Tahoe-LAFS distributed storage system integrated with your Project Earthgrid Tinc VPN.

## Table of Contents

1. [Understanding Tahoe-LAFS Concepts](#understanding-tahoe-lafs-concepts)
2. [Basic Operations](#basic-operations)
3. [Web Interface Usage](#web-interface-usage)
4. [Advanced Usage](#advanced-usage)
5. [Management and Monitoring](#management-and-monitoring)
6. [Backup Strategies](#backup-strategies)
7. [Troubleshooting](#troubleshooting)
8. [Performance Tuning](#performance-tuning)
9. [Security Considerations](#security-considerations)

## Understanding Tahoe-LAFS Concepts

### Core Concepts

Tahoe-LAFS (Least-Authority File System) is a distributed storage system with several key characteristics:

- **Distributed**: Data is spread across multiple nodes
- **Secure**: End-to-end encryption ensures data privacy
- **Fault-tolerant**: Data remains available even if multiple nodes fail
- **Free and open-source**: Can be audited and modified

### Key Terms

- **Introducer**: Helps nodes discover each other (think of it as a "phonebook")
- **Storage Node**: Stores encrypted shares of files
- **Client Node**: Used to read/write files to the grid
- **Web Gateway**: Provides a browser interface to the storage grid
- **Capability**: A cryptographic token that grants access to a file or directory
- **Share**: A fragment of encrypted data stored on a storage node
- **RAID-like redundancy**: Files are split into shares using erasure coding

### How Tahoe-LAFS Stores Files

When you upload a file to Tahoe-LAFS:

1. The client encrypts the file
2. The file is split into multiple "shares" using erasure coding
3. These shares are distributed to different storage nodes
4. A capability (a long string) is returned that allows access to the file
5. You only need a subset of shares to reconstruct the file (e.g., 3-of-10)

## Basic Operations

### Command Line Interface

Tahoe-LAFS provides a command-line tool for interacting with the grid. All commands should be run as the tahoe user:

```bash
sudo -u tahoe <command>
```

### Setting Up Aliases

Before using the grid, create an alias to simplify access:

```bash
sudo -u tahoe tahoe create-alias grid
```

This creates a shorthand "grid:" that points to a directory in the storage system.

### Working with Files and Directories

#### Create a Directory

```bash
sudo -u tahoe tahoe mkdir grid:documents
```

#### Uploading Files

```bash
# Upload a single file
sudo -u tahoe tahoe put /path/to/local/file.txt grid:documents/file.txt

# Upload a directory (recursively)
sudo -u tahoe tahoe cp -r /path/to/local/directory grid:documents/
```

#### Downloading Files

```bash
# Download a single file
sudo -u tahoe tahoe get grid:documents/file.txt /path/to/local/destination.txt

# Download a directory (recursively)
sudo -u tahoe tahoe cp -r grid:documents/ /path/to/local/directory/
```

#### Listing Contents

```bash
# List directory contents
sudo -u tahoe tahoe ls grid:documents/

# Detailed listing
sudo -u tahoe tahoe ls -l grid:documents/
```

#### Deleting Files and Directories

```bash
# Delete a file
sudo -u tahoe tahoe rm grid:documents/file.txt

# Delete a directory
sudo -u tahoe tahoe rm -r grid:documents/subdirectory/
```

### Working with Capabilities

Every file and directory in Tahoe-LAFS has a capability URI that grants access to it:

```bash
# Get the capability for a file
sudo -u tahoe tahoe manifest grid:documents/file.txt
```

Example capability: `URI:CHK:v2onswbpd6golqe4kfzb7gy3za:qwxpogyhabzmyrwv7vzxd7ad5f64e4s7t5uuddvjvarimqj7n5ta:3:10:31323`

There are three types of capabilities:
- **Read-write capability**: Allows reading and modifying
- **Read-only capability**: Allows only reading
- **Verify capability**: Allows checking if data exists without reading it

To use a capability directly:

```bash
# Use a capability to download a file
sudo -u tahoe tahoe get URI:CHK:v2onswbpd6golqe4kfzb7gy3za:qwxpogyhabzmyrwv7vzxd7ad5f64e4s7t5uuddvjvarimqj7n5ta:3:10:31323 /path/to/local/file
```

## Web Interface Usage

If you have a node with the web gateway role, you can access your files through a browser.

### Accessing the Web Interface

Access the web interface at: `http://[node-vpn-ip]:3456/`

### Navigating the Web Interface

1. **Home Page**: Shows available aliases (like "grid:")
2. **Directory View**: Lists files and directories
3. **File View**: Shows file contents or download options

### Uploading Files via Web Interface

1. Navigate to the target directory
2. Click the "Upload a File" button
3. Select the file from your local system
4. Click "Upload"

### Managing Files and Directories

- **Create Directory**: Use the "Create a Directory" button
- **Delete Files/Directories**: Click the "More Info" link next to the item, then "Delete"
- **Download Files**: Click the filename, then choose "Save As"

### Sharing Files and Directories

1. Navigate to the file/directory
2. Click "More Info"
3. Copy the appropriate capability URI (read-write, read-only, or verify)
4. Share this URI with others who need access

## Advanced Usage

### Custom Redundancy Settings

You can specify custom redundancy parameters when uploading files:

```bash
# Upload with custom redundancy (need 2-of-5 shares to recover)
sudo -u tahoe tahoe put --shares-needed=2 --shares-happy=4 --shares-total=5 /path/to/file.txt grid:custom-file.txt
```

- `shares-needed`: Minimum number of shares needed to recover the file
- `shares-happy`: Number of distinct servers that must have shares
- `shares-total`: Total number of shares to create

### Immutable vs. Mutable Files

By default, files uploaded to Tahoe-LAFS are immutable (cannot be changed).

For mutable files:

```bash
# Create a mutable file
sudo -u tahoe tahoe put --mutable /path/to/file.txt grid:mutable-file.txt

# Update a mutable file
sudo -u tahoe tahoe put --mutable-file-cap=$(sudo -u tahoe tahoe manifest grid:mutable-file.txt) /path/to/new-content.txt
```

### Mounting with FUSE

You can mount your Tahoe-LAFS grid as a local filesystem using FUSE:

```bash
# Install FUSE support
sudo apt-get install fuse python3-fuse

# Mount the grid
mkdir ~/tahoe-mount
sudo -u tahoe tahoe mount ~/tahoe-mount grid:
```

Now you can interact with your Tahoe grid using normal file operations!

### Creating Private Storage Areas

You can create separate aliases for different purposes:

```bash
# Create aliases for different purposes
sudo -u tahoe tahoe create-alias personal
sudo -u tahoe tahoe create-alias shared
sudo -u tahoe tahoe create-alias backups
```

## Management and Monitoring

### Checking Grid Health

```bash
# See overall grid statistics
sudo -u tahoe tahoe statistics gatherer-uri

# Check connectivity to storage servers
sudo -u tahoe tahoe ping-all
```

### Monitoring Storage Space

```bash
# Check storage usage across the grid
sudo -u tahoe tahoe disk-usage
```

### Server Statistics

To view detailed server statistics:

```bash
# Get statistics from the introducer
sudo -u tahoe tahoe admin get-introducer-status

# Get statistics from a storage server
sudo -u tahoe tahoe admin get-server-status
```

### Managing Shares

```bash
# List all shares stored on a node
sudo -u tahoe tahoe admin list-share-files

# Find which servers have shares for a file
sudo -u tahoe tahoe locate-file grid:documents/file.txt
```

## Backup Strategies

### Automated Backups to Tahoe-LAFS

Set up a cron job to perform regular backups:

```bash
# Create a backup script
cat > /opt/project-earthgrid/scripts/backup-to-tahoe.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y-%m-%d)
tar -czf /tmp/backup-$DATE.tar.gz /path/to/backup/directory
sudo -u tahoe tahoe put /tmp/backup-$DATE.tar.gz grid:backups/backup-$DATE.tar.gz
rm /tmp/backup-$DATE.tar.gz
EOF

chmod +x /opt/project-earthgrid/scripts/backup-to-tahoe.sh

# Add to crontab
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/project-earthgrid/scripts/backup-to-tahoe.sh") | crontab -
```

### Retention Policies

Create a script to implement a retention policy:

```bash
cat > /opt/project-earthgrid/scripts/backup-retention.sh << 'EOF'
#!/bin/bash
# Keep daily backups for 7 days, weekly for 4 weeks, monthly for 12 months

# Get list of backups
BACKUPS=$(sudo -u tahoe tahoe ls grid:backups/)

# Delete backups older than 7 days except weekly and monthly
# (implementation logic here)
EOF

chmod +x /opt/project-earthgrid/scripts/backup-retention.sh
```

## Troubleshooting

### Common Issues and Solutions

#### Cannot Connect to the Grid

**Symptoms**: Commands fail with connection errors, "No connections to storage servers" messages

**Solutions**:
- Check that the introducer is running: `sudo systemctl status tahoe-introducer`
- Verify VPN connectivity: `ping 172.16.0.x` (other node's VPN IP)
- Check introducer FURL is correct in configuration: `cat /opt/tahoe-lafs/storage/tahoe.cfg | grep introducer.furl`
- Restart the services: `sudo systemctl restart tahoe-storage`

#### Cannot Upload/Download Files

**Symptoms**: Operations fail with error messages about insufficient shares

**Solutions**:
- Check how many storage nodes are online:
  ```bash
  sudo -u tahoe tahoe statistics gatherer-uri | grep online
  ```
- Ensure you have enough nodes to satisfy your redundancy parameters
- Verify storage servers have free space: `sudo -u tahoe tahoe disk-usage`

#### Web Interface Not Working

**Symptoms**: Cannot access web interface or errors in browser

**Solutions**:
- Check if the web service is running: `sudo systemctl status tahoe-web`
- Verify correct port configuration: `cat /opt/tahoe-lafs/client/tahoe.cfg | grep web.port`
- Check web access logs: `sudo journalctl -u tahoe-web`

#### Slow Performance

**Symptoms**: Operations are unusually slow

**Solutions**:
- Check network latency between nodes: `ping 172.16.0.x`
- Verify if any storage nodes are overloaded: `sudo -u tahoe tahoe disk-usage`
- Consider adjusting redundancy parameters for less overhead

### Diagnostic Commands

```bash
# Check node status
sudo -u tahoe tahoe node-status

# Debug output from the client
sudo -u tahoe tahoe --debug run

# Check for errors in the logs
sudo journalctl -u tahoe-storage -p err

# Test upload/download speed
time sudo -u tahoe tahoe put /path/to/testfile grid:testfile
time sudo -u tahoe tahoe get grid:testfile /dev/null
```

## Performance Tuning

### Configuration Optimization

Edit the configuration files for optimal performance:

```bash
# Storage node configuration (/opt/tahoe-lafs/storage/tahoe.cfg)
[node]
log_gatherer.furl = pb://...
timeout.disconnect = 600
timeout.keepalive = 240

[storage]
# Disable reserved space for better performance if space isn't an issue
reserved_space = 1G
```

### Redundancy Trade-offs

Adjust the redundancy parameters in your client configuration:

```bash
# Lower redundancy for better performance (but less reliability)
[client]
shares.needed = 2
shares.happy = 3
shares.total = 5

# Higher redundancy for better reliability (but slower performance)
[client]
shares.needed = 3
shares.happy = 7
shares.total = 10
```

### Hardware Considerations

For best performance:
- Use SSDs for storage nodes when possible
- Ensure adequate RAM (at least 1GB per node)
- Stable, low-latency network connections between nodes

## Security Considerations

### Access Control

Tahoe-LAFS uses capability-based security:

- Keep capability strings private - they are equivalent to passwords
- Use read-only capabilities when full access isn't needed
- Consider creating different aliases for different security levels

### Physical Security

Remember that anyone with physical access to storage nodes could potentially:
- Access encrypted data (though they would need capabilities to read it)
- Disrupt storage by removing the node
- Compromise the node if they have root access

### Backup Capabilities

Always back up important capabilities:

```bash
# Export all aliases with their capabilities
sudo -u tahoe tahoe list-aliases > /secure/location/tahoe-aliases-backup.txt
```

### Isolated Web Gateway

For better security, consider running the web gateway on a separate node with:
- No storage role
- Limited access
- Possibly behind an additional authentication layer

### Multi-factor Authentication

While Tahoe-LAFS itself doesn't support MFA, you can add this at the system level:
- Require SSH keys + password for node access
- Use a VPN client certificate + password
- Implement web gateway behind a reverse proxy with authentication

---

## Additional Resources

- [Official Tahoe-LAFS Documentation](https://tahoe-lafs.readthedocs.io/en/latest/)
- [Tahoe-LAFS GitHub Repository](https://github.com/tahoe-lafs/tahoe-lafs)
- [LeastAuthority (Tahoe-LAFS creators)](https://leastauthority.com/)

---

For more assistance or to report issues, please file a ticket in the Project Earthgrid repository.
