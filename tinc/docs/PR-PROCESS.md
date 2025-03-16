# Public Key Pull Request Process

This document outlines the process for adding new nodes to the tinc VPN network through pull requests.

## Overview

For security reasons, adding new public keys to the VPN network requires a review process. This is implemented using GitHub pull requests, allowing administrators to review and approve new nodes before they can join the network.

## Process for Node Administrators

When setting up a new node:

1. Follow the standard bootstrap procedure
2. When keys are generated, follow these steps to submit them:

   ```bash
   # 1. Create a new branch
   cd /opt/project-earthgrid
   git checkout -b add-node-mynodename
   
   # 2. Add and commit the public key
   git add tinc/hosts/mynodename
   git commit -m "Add public key for mynodename"
   
   # 3. Push to your fork
   git push origin add-node-mynodename
   ```

3. Visit the GitHub repository in your browser
4. Create a new pull request from your branch
5. Fill out the PR template with node details (location, purpose, administrator)
6. Wait for approval from a network administrator

## Process for Network Administrators

When reviewing a new node PR:

1. Verify the requestor has legitimate access to the network
2. Review the public key file to ensure it:
   - Contains a valid tinc public key
   - Has proper Subnet information
   - Matches the node configuration in tinc/inventory/nodes.yml
3. Check for any potentially conflicting configurations
4. Approve and merge the PR
5. Deploy the updated configuration to all nodes

## After PR Approval

Once the PR is approved and merged:

1. The node administrator should update their local repository:
   ```bash
   cd /opt/project-earthgrid
   git checkout main
   git pull
   ```

2. The new node will now be able to connect to the network

## PR Template

When creating a PR, include the following information:

```
## Node Information
- **Node Name**: mynodename
- **VPN IP**: 172.16.0.X
- **Location**: (physical/geographical location)
- **Purpose**: (what this node will be used for)
- **Administrator**: (who manages this node)

## Checklist
- [ ] Node added to inventory/nodes.yml
- [ ] Public key generated and added
- [ ] No IP conflicts with existing nodes
```
