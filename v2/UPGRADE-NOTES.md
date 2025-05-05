# Project Earthgrid v2 Upgrade Notes

This document outlines the changes made during the v2 refactoring of Project Earthgrid, focusing on the Tinc VPN infrastructure and GPG-based authentication.

## What's New in v2

### Architecture Changes

- **Container-Based Deployment**: Complete Docker container setup with Docker Compose
- **GPG Authentication**: Secure node identity verification using GPG keys
- **Auto-Discovery Mechanism**: Nodes automatically discover and connect to peers
- **Manifest-Based Configuration**: Centralized configuration via Git repository
- **Improved Security**: Enhanced key management and authentication

### Directory Structure

The v2 implementation follows a more organized structure:

```
v2/
├── Docker/
│   ├── earthgrid-tinc/         # Tinc VPN container files
│   │   ├── Dockerfile
│   │   ├── scripts/            # Container scripts
│   │   ├── config/             # Configuration templates
│   │   └── supervisord.conf    # Process management
│   ├── data/                   # Runtime data (created during deployment)
│   │   ├── tinc/               # Tinc configuration
│   │   ├── gnupg/              # GPG keyring
│   │   ├── logs/               # Log files
│   │   ├── manifest-repo/      # Cloned manifest repository
│   │   └── manifest/           # Working manifest files
│   ├── docker-compose.yml      # Container orchestration
│   ├── .env                    # Environment variables
│   └── secrets/                # Secret key storage
├── manifest/                   # Network manifest definition
│   └── manifest.yaml           # Node definitions
├── docs/                       # Documentation
│   ├── GPG-KEY-MANAGEMENT.md
│   └── NODE-DEPLOYMENT.md
├── README.md                   # Project overview
├── setup.sh                    # Setup script
└── UPGRADE-NOTES.md            # This file
```

## Key Features Implemented

1. **Tinc VPN Container**:
   - Complete Dockerfile with required dependencies
   - Script-based configuration and management
   - Supervisor to manage multiple processes
   - Auto-scaling mesh network

2. **GPG Key Management**:
   - Key generation, import/export tools
   - GPG-based node authentication
   - Docker secret integration
   - Secure key handling

3. **Node Auto-Discovery**:
   - Automatic synchronization with manifest
   - Periodic configuration updates
   - Dynamic connection management
   - Centralized network topology

4. **Documentation**:
   - Comprehensive README with overview
   - Detailed deployment guide
   - GPG key management documentation
   - Troubleshooting instructions

## Migration from v1

To migrate an existing node from v1 to v2:

1. **Backup your configuration**:
   ```bash
   cp -r /etc/tinc /backup/tinc
   ```

2. **Generate a GPG key pair** (if you don't already have one)

3. **Add your node to the v2 manifest.yaml** file with the same IP address

4. **Run the v2 setup script**:
   ```bash
   cd project-earthgrid/v2
   ./setup.sh
   ```

5. **Verify connectivity** with other nodes

## Next Steps

The v2 implementation lays the groundwork for the full Earthgrid vision. Future development will focus on:

1. **Tahoe-LAFS Integration**: Implementing the distributed storage layer
2. **Storage Management**: Quota and allocation systems
3. **User Interfaces**: Web and mobile access
4. **Monitoring & Metrics**: Performance tracking and optimization
5. **Backup Client**: Automated backup tools

## Reporting Issues

If you encounter any issues with the v2 implementation, please report them on the GitHub repository with:

1. A clear description of the problem
2. Steps to reproduce the issue
3. Log output (remove any sensitive information)
4. Environment details (OS, Docker version, etc.)

## Contributors

The v2 refactoring was implemented with contributions from:

- Project Earthgrid Team members
- Community contributors