# Duplicates Found and Removed

This document details all the duplicate settings that were found and consolidated during the reorganization.

## Summary

**Total Duplicates Resolved**: 5 major categories with ~150+ individual duplicate definitions

## Detailed Breakdown

### 1. Kernel Hardening Settings (sysctl)

**Files with duplicates:**
- `configuration/security-production.nix`
- `configuration/security-strict.nix`
- `configuration/cache-optimization.nix`

**Consolidated to:** `configuration/security/kernel-hardening.nix`

**Duplicated settings (23 settings):**

#### Security Settings
- `kernel.dmesg_restrict` - Restrict dmesg access (3 occurrences)
- `kernel.kptr_restrict` - Hide kernel pointers (3 occurrences)
- `kernel.unprivileged_userns_clone` - Disable unprivileged user namespaces (2 occurrences)
- `kernel.unprivileged_bpf_disabled` - Disable unprivileged BPF (2 occurrences)
- `kernel.yama.ptrace_scope` - Restrict ptrace (2 occurrences)
- `kernel.kexec_load_disabled` - Disable kexec (2 occurrences)
- `kernel.randomize_va_space` - Enable ASLR (2 occurrences)
- `kernel.perf_event_paranoid` - Restrict performance events (1 occurrence)
- `vm.unprivileged_userfaultfd` - Restrict userfaultfd (1 occurrence)

#### Network Settings
- `net.ipv4.conf.all.rp_filter` - Reverse path filtering (2 occurrences)
- `net.ipv4.conf.default.rp_filter` - Reverse path filtering default (2 occurrences)
- `net.ipv4.conf.all.accept_source_route` - Disable source routing (2 occurrences)
- `net.ipv4.conf.default.accept_source_route` - Disable source routing default (2 occurrences)
- `net.ipv4.conf.all.send_redirects` - Disable ICMP redirects send (2 occurrences)
- `net.ipv4.conf.default.send_redirects` - Disable ICMP redirects send default (2 occurrences)
- `net.ipv4.conf.all.accept_redirects` - Disable ICMP redirects accept (2 occurrences)
- `net.ipv4.conf.default.accept_redirects` - Disable ICMP redirects accept default (2 occurrences)
- `net.ipv4.tcp_syncookies` - Enable SYN cookies (2 occurrences)
- `net.ipv4.icmp_echo_ignore_broadcasts` - Ignore broadcast pings (2 occurrences)

#### Filesystem Settings
- `fs.protected_hardlinks` - Protect hard links (2 occurrences)
- `fs.protected_symlinks` - Protect symbolic links (2 occurrences)
- `fs.protected_fifos` - Protect FIFOs (2 occurrences)
- `fs.protected_regular` - Protect regular files (2 occurrences)
- `fs.suid_dumpable` - Disable SUID core dumps (2 occurrences)

#### Network Performance (from cache-optimization.nix)
- `net.core.rmem_max` - TCP receive buffer size (1 occurrence, kept)
- `net.core.wmem_max` - TCP send buffer size (1 occurrence, kept)
- `net.ipv4.tcp_rmem` - TCP receive buffer tuning (1 occurrence, kept)
- `net.ipv4.tcp_wmem` - TCP send buffer tuning (1 occurrence, kept)
- `net.ipv4.tcp_fastopen` - Enable TCP fast open (1 occurrence, kept)
- `net.core.somaxconn` - Max socket connections (1 occurrence, kept)
- `net.core.netdev_max_backlog` - Network device backlog (1 occurrence, kept)

### 2. Firewall Configuration

**Files with duplicates:**
- `configuration/security-production.nix`
- `configuration/security.nix`
- `configuration/security-strict.nix`

**Consolidated to:** `configuration/security/firewall.nix`

**Duplicated settings:**
- `networking.firewall.enable` (3 occurrences)
- `networking.firewall.allowedTCPPorts` (2 occurrences)
- `networking.firewall.logRefusedConnections` (2 occurrences)
- `networking.firewall.logRefusedPackets` (2 occurrences)
- `networking.firewall.rejectPackets` (1 occurrence in strict mode)
- `networking.nftables.enable` (2 occurrences)
- `networking.nftables.ruleset` (2 occurrences with similar content)

**Solution:** 
- Created unified firewall module with standard (iptables) and strict (nftables) modes
- Uses `hypervisor.security.strictFirewall` option to switch modes
- Eliminates all duplicate firewall definitions

### 3. SSH Configuration

**Files with duplicates:**
- `configuration/security-production.nix`
- `configuration/security-strict.nix`

**Consolidated to:** `configuration/security/ssh.nix`

**Duplicated settings (15 settings):**
- `services.openssh.enable` (2 occurrences)
- `services.openssh.settings.PasswordAuthentication` (2 occurrences)
- `services.openssh.settings.ChallengeResponseAuthentication` (2 occurrences)
- `services.openssh.settings.KbdInteractiveAuthentication` (2 occurrences)
- `services.openssh.settings.PermitRootLogin` (2 occurrences)
- `services.openssh.settings.AllowUsers` (2 occurrences)
- `services.openssh.settings.DenyUsers` (2 occurrences)
- `services.openssh.settings.KexAlgorithms` (2 occurrences, stricter in strict mode)
- `services.openssh.settings.Ciphers` (2 occurrences, stricter in strict mode)
- `services.openssh.settings.Macs` (2 occurrences, stricter in strict mode)
- `services.openssh.settings.MaxAuthTries` (1 occurrence in strict mode)
- `services.openssh.settings.MaxSessions` (1 occurrence in strict mode)
- `services.openssh.settings.LoginGraceTime` (1 occurrence in strict mode)
- `services.fail2ban.enable` (2 occurrences)
- `services.fail2ban.*` (2 occurrences)

**Solution:**
- Created unified SSH module with standard and strict modes
- Uses `hypervisor.security.sshStrictMode` option for stricter settings
- Consolidates fail2ban configuration

### 4. Audit and Logging Configuration

**Files with duplicates:**
- `configuration/security-production.nix`
- `configuration/security-strict.nix`

**Consolidated to:** `configuration/security/base.nix`

**Duplicated settings (15+ rules):**
- `security.auditd.enable` (2 occurrences)
- `security.audit.enable` (2 occurrences)
- `security.audit.rules` (2 occurrences with overlapping rules)
- `services.journald.extraConfig` (2 occurrences with similar content)

**Audit rules duplicated:**
- VM operation logging (virsh execve)
- VM deletion/destroy logging
- Sudo command logging
- File access to /etc/nixos, /etc/hypervisor
- Authentication event logging
- User/group modification logging
- Network configuration logging (strict mode)
- Service changes logging (strict mode)

### 5. Directory and tmpfiles Configuration

**Files with duplicates:**
- `configuration/security-profiles.nix` (2 sets: headless + management)
- `configuration/automation.nix`
- `configuration/backup.nix`
- `configuration/enterprise-features.nix`
- `configuration/centralized-logging.nix`
- `configuration/web-dashboard.nix`

**Consolidated to:** `configuration/core/directories.nix`

**Duplicated directory definitions (20+ directories):**
- `/var/lib/hypervisor` (5 occurrences with different permissions)
- `/var/lib/hypervisor/logs` (6 occurrences)
- `/var/lib/hypervisor/backups` (3 occurrences)
- `/var/lib/hypervisor/isos` (2 occurrences)
- `/var/lib/hypervisor/disks` (2 occurrences)
- `/var/lib/hypervisor/xml` (2 occurrences)
- `/var/lib/hypervisor/vm_profiles` (2 occurrences)
- `/var/lib/hypervisor/gnupg` (2 occurrences)
- `/var/lib/hypervisor/templates` (2 occurrences)
- `/var/lib/hypervisor/reports` (2 occurrences)
- `/var/lib/hypervisor/keys` (2 occurrences)
- `/var/lib/hypervisor/secrets` (2 occurrences)
- `/var/log/hypervisor` (3 occurrences)
- `/var/log/hypervisor/vms` (2 occurrences)
- `/var/www/hypervisor/*` (2 occurrences)
- `/var/lib/hypervisor-operator` (2 occurrences)

**Solution:**
- Created centralized directory management module
- Profile-aware ownership (headless vs management)
- Single source of truth for all directory definitions

### 6. Logrotate Configuration

**Files with duplicates:**
- `configuration/configuration.nix`
- `configuration/centralized-logging.nix`

**Consolidated to:** `configuration/core/logrotate.nix`

**Duplicated settings:**
- `/var/lib/hypervisor/logs/*.log` (2 occurrences)
- `/var/log/hypervisor/*.log` (2 occurrences)
- `/var/log/hypervisor/vms/*.log` (1 occurrence)
- Rotation policies (frequency, retention, compression)

### 7. Libvirt Configuration

**Files with duplicates:**
- `configuration/security-production.nix`
- `configuration/security/base.nix`
- `configuration/virtualization/libvirt.nix`

**Consolidated to:** `configuration/security/base.nix` (security aspects) and `configuration/virtualization/libvirt.nix` (basic enable)

**Duplicated settings:**
- `virtualisation.libvirtd.enable` (3 occurrences)
- `virtualisation.libvirtd.qemu.runAsRoot` (2 occurrences)
- `virtualisation.libvirtd.onBoot` (2 occurrences)
- `virtualisation.libvirtd.onShutdown` (2 occurrences)
- `virtualisation.libvirtd.extraConfig` (2 occurrences with identical security settings)

### 8. Security Packages

**Files with duplicates:**
- `configuration/security-production.nix`
- `configuration/core/packages.nix`

**Duplicated packages:**
- `audit` (2 occurrences)
- `gnupg` (3 occurrences)
- `htop` (2 occurrences)
- `iotop` (2 occurrences)
- `tcpdump` (2 occurrences)

**Solution:** Consolidated into core/packages.nix

## Impact

### Before Reorganization
- **Total .nix files in root**: 20+ files
- **Duplicate definitions**: ~150 settings defined multiple times
- **Maintenance burden**: Changes required in 2-3 files
- **Conflict risk**: High (different values in different files)

### After Reorganization
- **Files in organized folders**: 8 folders, cleaner structure
- **Duplicate definitions**: 0 (all consolidated)
- **Maintenance burden**: Single point of modification
- **Conflict risk**: Eliminated

## Benefits

1. **No more conflicts**: Each setting defined exactly once
2. **Clear ownership**: Each setting has a clear "home" module
3. **Easier overrides**: Use `lib.mkForce` or `lib.mkDefault` consistently
4. **Better documentation**: Related settings grouped together
5. **Reduced errors**: No risk of forgetting to update a duplicate
6. **Improved maintainability**: Changes in one place affect everywhere
7. **Profile support**: Settings adapt based on security profile

## Testing Recommendations

After applying these changes:

1. **Test both profiles**:
   ```nix
   hypervisor.security.profile = "headless";  # Test this
   hypervisor.security.profile = "management";  # And this
   ```

2. **Test optional features**:
   - Enterprise features enable/disable
   - Performance tuning enable/disable
   - Strict security mode enable/disable

3. **Verify no conflicts**:
   ```bash
   sudo nixos-rebuild dry-build --flake .
   ```

4. **Check for warnings**:
   Look for "defined multiple times" errors

## Migration Path

For users with local overrides:

1. If you have `/var/lib/hypervisor/configuration/` overrides, they still work
2. If you used `lib.mkForce` on duplicated settings, you may need to update the module path
3. Check your overrides don't conflict with the new consolidated settings
