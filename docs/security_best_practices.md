# Hypervisor Security Best Practices

This guide provides comprehensive security recommendations for operating your NixOS-based hypervisor system.

## 1. Host Hardening

### Kernel Security
- **Hardened Kernel**: Already enabled via `boot.kernelPackages = pkgs.linuxPackages_hardened`
- **Security Parameters**: Key sysctls are configured in `configuration.nix`
- **Recommendations**:
  - Review and adjust kernel parameters based on workload
  - Consider enabling additional mitigations for specific threats
  - Monitor kernel security advisories

### Access Control
- **SSH Hardening**: Key-only authentication is enforced
- **User Management**:
  ```bash
  # Create separate admin accounts
  sudo useradd -m -G wheel,kvm,libvirtd admin-user
  
  # Implement sudo rules with specific commands
  echo "admin-user ALL=(ALL) /usr/bin/virsh, /etc/hypervisor/scripts/*" | sudo tee /etc/sudoers.d/hypervisor-admins
  ```

### Audit Logging
- **auditd**: Enabled by default
- **Enhanced Rules**:
  ```bash
  # Add custom audit rules
  cat > /etc/audit/rules.d/hypervisor.rules << EOF
  # VM lifecycle events
  -w /var/lib/libvirt/qemu/ -p wa -k vm_changes
  -w /etc/hypervisor/vm_profiles/ -p wa -k vm_config
  
  # Authentication
  -w /var/log/auth.log -p wa -k auth_log
  -w /etc/shadow -p wa -k shadow_changes
  
  # Network configuration
  -w /etc/nftables.conf -p wa -k firewall_changes
  EOF
  ```

## 2. VM Isolation

### Network Segmentation
- **Zone-based Isolation**:
  - `secure`: For trusted VMs with potential host access
  - `untrusted`: For isolated VMs with no host access
  - Custom zones for specific security requirements

### Resource Limits
- **CPU/Memory Quotas**: Enforced via systemd slices
- **Disk I/O Limits**: Configure in VM profiles:
  ```json
  {
    "limits": {
      "cpu_quota_percent": 200,
      "memory_max_mb": 8192,
      "io_bandwidth_mb": 100
    }
  }
  ```

### AppArmor Profiles
- **QEMU Confinement**: Custom profile at `/etc/hypervisor/configuration/apparmor/qemu-system-x86_64`
- **Per-VM Profiles**: Create specific profiles for sensitive VMs:
  ```bash
  # Generate VM-specific AppArmor profile
  sudo aa-genprof /usr/bin/qemu-system-x86_64
  ```

## 3. Secure VM Configuration

### UEFI Secure Boot
- Enable for supported guest OSes:
  ```json
  {
    "firmware": {
      "secure_boot": true,
      "enrolled_keys": "/var/lib/hypervisor/secureboot/keys/"
    }
  }
  ```

### Memory Encryption (AMD SEV)
- For sensitive workloads on AMD EPYC:
  ```json
  {
    "cpu_features": {
      "sev": true,
      "sev_es": true,
      "sev_snp": true
    },
    "memory_options": {
      "guest_memfd": true,
      "private": true
    }
  }
  ```

### TPM Support
- Virtual TPM for guest attestation:
  ```json
  {
    "tpm": {
      "version": "2.0",
      "model": "tpm-crb"
    }
  }
  ```

## 4. Network Security

### Firewall Configuration
- **Default Deny**: Strict nftables rules via `security.nix`
- **Per-VM Rules**: Use `per_vm_firewall.sh` for granular control
- **Example Zone Rules**:
  ```bash
  # Restrict untrusted zone
  sudo nft add rule inet filter forward iifname "br-untrusted" oifname != "br-untrusted" drop
  ```

### VPN Integration
- Route sensitive VMs through VPN:
  ```bash
  # Create VPN bridge
  sudo ip link add br-vpn type bridge
  sudo ip link set br-vpn up
  
  # Configure in VM profile
  {
    "network": {
      "bridge": "br-vpn",
      "zone": "vpn-only"
    }
  }
  ```

## 5. Monitoring and Incident Response

### Security Monitoring
- **Enable Prometheus Stack**:
  ```nix
  # In configuration.nix
  imports = [ ./monitoring.nix ];
  hypervisor.monitoring = {
    enablePrometheus = true;
    enableGrafana = true;
    enableAlertmanager = true;
  };
  ```

### Log Aggregation
- Centralize logs for analysis:
  ```bash
  # Configure rsyslog forwarding
  echo "*.* @@siem-server:514" | sudo tee -a /etc/rsyslog.conf
  ```

### Incident Response Plan
1. **Detection**: Monitor alerts from Prometheus/Alertmanager
2. **Containment**: Use zone isolation to quarantine compromised VMs
3. **Investigation**: Review audit logs and VM snapshots
4. **Recovery**: Restore from verified backups

## 6. Backup and Recovery

### Automated Backups
- Configure regular VM backups:
  ```bash
  # Add to crontab
  0 2 * * * /etc/hypervisor/scripts/snapshots_backups.sh --all --destination /backup/vms/
  ```

### Backup Encryption
- Encrypt backups at rest:
  ```bash
  # Initialize GPG for backups
  gpg --homedir /var/lib/hypervisor/gnupg --gen-key
  
  # Encrypt backup script
  tar czf - /var/lib/hypervisor/disks/vm.qcow2 | \
    gpg --homedir /var/lib/hypervisor/gnupg --encrypt -r backup@hypervisor > vm-backup.tar.gz.gpg
  ```

## 7. Compliance and Hardening

### CIS Benchmarks
- Apply CIS hardening guidelines:
  ```bash
  # Download and run CIS-CAT tool
  # Review and implement recommendations
  ```

### Regular Updates
- **System Updates**: Use the menu option or:
  ```bash
  sudo /etc/hypervisor/scripts/update_hypervisor.sh
  ```
- **Security Patches**: Monitor NixOS security advisories

### Security Scanning
- Regular vulnerability assessments:
  ```bash
  # Host scanning
  sudo nix-shell -p nmap --run "nmap -sV localhost"
  
  # VM scanning (from isolated network)
  sudo nix-shell -p openvas --run "openvas-check-setup"
  ```

## 8. Operational Security

### Change Management
- Document all configuration changes
- Use version control for custom configurations:
  ```bash
  cd /var/lib/hypervisor
  git init
  git add vm_profiles/ configuration/
  git commit -m "Initial hypervisor configuration"
  ```

### Access Reviews
- Regular audit of user access:
  ```bash
  # List users with VM access
  getent group libvirtd kvm
  
  # Review sudo permissions
  sudo -l -U username
  ```

### Security Training
- Ensure all administrators understand:
  - VM escape risks and mitigations
  - Network isolation principles
  - Incident response procedures
  - Backup and recovery processes

## Quick Security Checklist

- [ ] Kernel hardening enabled
- [ ] SSH key-only authentication
- [ ] Audit logging configured
- [ ] AppArmor profiles active
- [ ] Network zones configured
- [ ] Firewall rules reviewed
- [ ] VM resource limits set
- [ ] Monitoring enabled
- [ ] Backups encrypted and tested
- [ ] Update schedule defined
- [ ] Incident response plan documented
- [ ] Administrator training completed

## Emergency Procedures

### Suspected VM Compromise
1. Isolate VM immediately:
   ```bash
   virsh suspend suspicious-vm
   virsh detach-interface suspicious-vm --type bridge
   ```
2. Snapshot for forensics:
   ```bash
   virsh snapshot-create-as suspicious-vm --name incident-$(date +%Y%m%d-%H%M%S)
   ```
3. Review logs and alerts
4. Follow incident response plan

### Host Compromise
1. Disconnect network (physical if possible)
2. Preserve evidence (memory dump, disk image)
3. Boot from trusted media for investigation
4. Rebuild from known-good configuration

Remember: Security is an ongoing process. Regularly review and update these practices based on your threat model and operational requirements.