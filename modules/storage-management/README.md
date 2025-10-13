# Storage Management Module

This directory contains all storage-related configurations for VMs.

## Module Organization

### `quotas.nix`
Storage quota management:
- Disk space quotas per VM
- Storage pool limits
- Thin provisioning
- Usage alerts and monitoring
- Prevents storage exhaustion

**When to edit**: Setting disk space limits, managing storage pools

### `encryption.nix`
VM disk encryption:
- LUKS2 encryption for VM disks
- Secure key management
- AES-256-XTS encryption
- Automatic disk unlock
- Passphrase management

**When to edit**: Enabling encryption for sensitive VMs, managing encryption keys

## Common Tasks

### Set Storage Quota for a VM
```bash
# Set 50GB quota
/etc/hypervisor/scripts/storage_quota.sh set web-server 50

# Check current usage
/etc/hypervisor/scripts/storage_quota.sh get web-server

# Expand to 100GB
/etc/hypervisor/scripts/storage_quota.sh expand web-server 100

# Set alert at 80% usage
/etc/hypervisor/scripts/storage_quota.sh alert-threshold web-server 80
```

Or edit `quotas.nix` to configure default storage quotas.

### Create Encrypted VM Disk
```bash
# Create new 50GB encrypted disk
/etc/hypervisor/scripts/vm_encryption.sh create-encrypted secure-vm 50

# Encrypt existing disk
/etc/hypervisor/scripts/vm_encryption.sh encrypt-existing web-server /var/lib/libvirt/images/web.qcow2

# Change encryption passphrase
/etc/hypervisor/scripts/vm_encryption.sh change-passphrase secure-vm

# List encrypted VMs
/etc/hypervisor/scripts/vm_encryption.sh list-encrypted
```

Or edit `encryption.nix` to configure encryption defaults.

### Monitor Storage Usage
```bash
# List all storage quotas
/etc/hypervisor/scripts/storage_quota.sh list

# Check quota enforcement
/etc/hypervisor/scripts/storage_quota.sh check

# View storage pool usage
virsh pool-list --all
virsh pool-info default
```

## Storage Features

### Disk Space Quotas
- **Thin provisioning**: VMs allocated space on-demand
- **Hard limits**: VMs cannot exceed quota
- **Alerts**: Notifications at configured thresholds
- **Automatic monitoring**: Systemd timer checks usage

### VM Disk Encryption
- **Algorithm**: AES-256-XTS (LUKS2)
- **Key derivation**: Argon2id
- **Key storage**: Encrypted at rest in `/var/lib/hypervisor/keys/`
- **Automatic unlock**: VMs start without manual intervention
- **Security**: Host compromise means all VMs compromised

## Best Practices

1. **Storage Quotas**:
   - Set quotas to prevent disk exhaustion
   - Use thin provisioning for efficiency
   - Monitor storage alerts regularly
   - Plan for 20-30% overhead

2. **Encryption**:
   - Enable for sensitive data VMs
   - Back up encryption keys securely
   - Store keys off-host for maximum security
   - Consider TPM integration for production
   - Test recovery procedures

3. **Storage Planning**:
   - Monitor growth trends
   - Clean up old snapshots
   - Use compression where appropriate
   - Archive unused VMs

## Security Considerations

### Encryption Key Management
- Keys stored in `/var/lib/hypervisor/keys/` (mode 700)
- Individual key files per VM (mode 400)
- **IMPORTANT**: If host is compromised, encrypted VMs are compromised
- For maximum security:
  - Store keys on external HSM or TPM
  - Use network-based key management
  - Require manual unlock for critical VMs

### Backup Considerations
- Encrypted VMs must be backed up encrypted
- Store encryption keys separately from VM backups
- Test restore procedures including key recovery

## See Also

- VM management: `../vm-management/`
- Backup configuration: `../automation/backup.nix`
- Security: `../security/`
