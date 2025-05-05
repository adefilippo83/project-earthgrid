# GPG Key Management for Project Earthgrid

This document provides detailed instructions for managing GPG keys in the Project Earthgrid network. GPG keys are used for node authentication and security in the VPN mesh.

## Introduction to GPG in Earthgrid

In Project Earthgrid, each node is identified by a unique GPG key. This key serves several purposes:

1. **Node Identity**: Uniquely identifies each node in the network
2. **Authentication**: Verifies the identity of nodes connecting to each other
3. **Security**: Prevents unauthorized nodes from joining the network
4. **Trust Model**: Establishes a web of trust within the network

## Key Generation

To generate a new GPG key pair for your node:

```bash
cd Docker/earthgrid-tinc
./scripts/manage-gpg-keys.sh generate "Node Name" "node@example.com"
```

This will create a 4096-bit RSA key pair with no expiration date. The output will display your key ID, which should be added to the manifest file.

### Key Properties

- **Type**: RSA
- **Length**: 4096 bits (strong encryption)
- **Expiration**: None (can be modified if needed)
- **Usage**: Signing and Encryption

## Key Distribution

After generating your key, you need to:

1. **Add your key ID to the manifest file** (located at `manifest/manifest.yaml`):
   ```yaml
   nodes:
     - name: yournode
       internal_ip: 10.100.1.X
       public_ip: auto
       gpg_key_id: YOUR_KEY_ID_HERE
       region: your-region
       status: active
   ```

2. **Upload your public key to a keyserver**:
   ```bash
   gpg --keyserver keys.openpgp.org --send-key YOUR_KEY_ID
   ```
   
   You can verify it was uploaded with:
   ```bash
   gpg --keyserver keys.openpgp.org --search-keys YOUR_KEY_ID
   ```

3. **Export your private key** for use in your node:
   ```bash
   ./scripts/manage-gpg-keys.sh export-private YOUR_KEY_ID ./secrets/gpg_private_key.asc
   ```

## Managing Keys

The `manage-gpg-keys.sh` script provides several functions to help manage your GPG keys:

### List Keys

```bash
./scripts/manage-gpg-keys.sh list
```

### Export Public Key

To stdout:
```bash
./scripts/manage-gpg-keys.sh export YOUR_KEY_ID
```

To a file:
```bash
./scripts/manage-gpg-keys.sh export YOUR_KEY_ID /path/to/output.asc
```

### Export Private Key

To stdout (be careful - your private key will be displayed):
```bash
./scripts/manage-gpg-keys.sh export-private YOUR_KEY_ID
```

To a file:
```bash
./scripts/manage-gpg-keys.sh export-private YOUR_KEY_ID /path/to/private-key.asc
```

### Import Key

```bash
./scripts/manage-gpg-keys.sh import /path/to/key.asc
```

### Delete Key

```bash
./scripts/manage-gpg-keys.sh delete YOUR_KEY_ID
```

## Key Rotation

For security purposes, you may want to periodically rotate your keys:

1. **Generate a new key pair**:
   ```bash
   ./scripts/manage-gpg-keys.sh generate "Node Name" "node@example.com"
   ```

2. **Update your node's configuration** with the new key ID

3. **Update the manifest file** with your new key ID

4. **Upload the new public key** to the keyserver

5. **Remove the old key** from your node once the transition is complete

## Security Best Practices

When using GPG keys in Project Earthgrid:

1. **Keep your private key secure** - never share it with anyone
2. **Use a strong passphrase** if using keys outside of the container
3. **Limit access** to your private key files
4. **Backup your keys** in a secure location
5. **Verify key fingerprints** when importing keys from others
6. **Consider key rotation** for critical infrastructure nodes 

## Troubleshooting

### Key Import Issues

If you have issues importing a key:
```bash
gpg --keyserver keys.openpgp.org --recv-keys KEY_ID --debug-level guru
```

### GPG Agent Problems

If GPG hangs when using your key:
```bash
gpgconf --kill gpg-agent
```

### Key Not Found

If the key server doesn't have your key:
1. Try a different key server (like `keyserver.ubuntu.com`)
2. Check if your Internet connection allows access to key servers
3. Verify the key ID is correct

### Signature Verification Failures

If signature verification fails:
1. Check if the node is using the correct key for signing
2. Ensure the manifest has the correct key ID
3. Verify the key has been properly imported

## References

- [GnuPG Manual](https://www.gnupg.org/documentation/manuals/gnupg/)
- [GPG Key Best Practices](https://github.com/drduh/YubiKey-Guide)
- [OpenPGP Best Practices](https://riseup.net/en/security/message-security/openpgp/best-practices)