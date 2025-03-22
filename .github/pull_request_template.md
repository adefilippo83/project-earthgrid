## Node Information
- **Node Name**: <!-- Your node name here -->
- **VPN IP**: <!-- Your VPN IP here, e.g., 172.16.0.X -->
- **Location**: <!-- Physical/geographical location -->
- **Purpose**: <!-- What this node will be used for -->
- **Administrator**: <!-- Who manages this node -->

## Tahoe-LAFS Configuration
- **Tahoe Roles**: <!-- Roles this node will perform (introducer, storage, client, web) -->
- **Storage Capacity**: <!-- Amount of storage to contribute (if storage role), e.g., 50GB -->
- **Web Port**: <!-- Port for web interface (if web role), e.g., 3456 -->

## Checklist
### VPN Configuration
- [ ] Node added to tinc/inventory/nodes.yml
- [ ] Public key generated and added to tinc/hosts/
- [ ] No IP conflicts with existing nodes
- [ ] Subnet in host file matches inventory

### Tahoe-LAFS Configuration (if applicable)
- [ ] Node added to tahoe/inventory/tahoe-nodes.yml
- [ ] Tahoe roles properly configured
- [ ] Storage capacity specified (if storage role)
- [ ] Web port specified (if web role)

## Additional Information
<!-- Provide any additional context or information about this node -->
