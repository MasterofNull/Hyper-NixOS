# Additional Security Considerations

Comprehensive checklist of security items to consider for production/compliance environments.

---

## Critical Security Gaps to Address

### 1. **VM Disk Encryption** ⚠️ CRITICAL

**Risk:** VM disks contain sensitive data, readable if host is compromised or disks are stolen.

**Current State:** ❌ Not encrypted by default

**Recommendation:**
```nix
# Enable LUKS encryption for VM disks
virtualisation.libvirtd.qemu.verbatimConfig = ''
  # Require disk encryption
  security_default_encrypted = 1
'';

# Or use virtio-crypto for VM-level encryption
```

**Implementation:**
- Use LUKS for host-level disk encryption
- Use dm-crypt for VM disk images
- Consider SEV (AMD) or TDX (Intel) for memory encryption
- Store encryption keys in hardware security module (HSM) or TPM

**Compliance:** Required for PCI-DSS, HIPAA, SOC2

---

### 2. **VM Backup Operations** ⚠️ IMPORTANT

**Risk:** Who can backup VMs? Where are backups stored? Are they encrypted?

**Current State:** ⚠️ Not clearly defined in operator permissions

**Recommendation:**

**Option A: Operator can backup (read-only)**
```nix
# Allow operator to create backups
security.polkit.extraConfig = ''
  polkit.addRule(function(action, subject) {
    if (subject.user == "hypervisor-operator" &&
        action.id == "org.libvirt.unix.manage") {
      var cmd = action.lookup("command_line");
      // Allow backup operations
      if (cmd && (cmd.indexOf("dumpxml") >= 0 ||
                  cmd.indexOf("save") >= 0 ||
                  cmd.indexOf("snapshot-create") >= 0)) {
        return polkit.Result.YES;
      }
    }
  });
'';
```

**Option B: Only admins can backup (more secure)**
- Backups contain full VM state including secrets
- Require admin privileges for backup creation
- Automated backups run as dedicated backup user

**Critical:** Encrypt all backups!
```bash
# Example: encrypted backups
gpg --encrypt --recipient admin@example.com vm-backup.qcow2
```

---

### 3. **VM Restore Operations** 🔒 PRIVILEGED

**Risk:** Restoring VMs can overwrite data, introduce malware, or bypass security.

**Current State:** ⚠️ Should require admin privileges

**Recommendation:**
```nix
# Restore is ADMIN-ONLY operation
# Operator cannot restore from backups
# Prevents:
# - Restoring malicious VM snapshots
# - Accidental data loss
# - Bypassing audit trails
```

**Rationale:**
- Restore operations are destructive
- Can be used to rollback security patches
- May contain old credentials or vulnerabilities
- Should require approval/authentication

---

### 4. **VM Resource Quotas** ⚠️ IMPORTANT

**Risk:** Operator creates too many VMs or VMs that are too large, causing DoS.

**Current State:** ❌ No quotas enforced

**Recommendation:**
```nix
# Implement quotas
systemd.services.hypervisor-quota-enforcement = {
  description = "Enforce VM resource quotas";
  script = ''
    # Max VMs per operator
    MAX_VMS=20
    
    # Max total CPU allocation
    MAX_CPUS=80  # % of host CPUs
    
    # Max total memory
    MAX_MEMORY=128000  # MB
    
    # Max disk per VM
    MAX_DISK_PER_VM=500  # GB
    
    # Implement checks before VM creation
  '';
};

# Or use libvirt quotas
virtualisation.libvirtd.extraConfig = ''
  max_clients = 20
  max_client_requests = 100
'';
```

**Implementation Ideas:**
- Pre-check available resources before VM creation
- Track resource usage per operator
- Implement approval workflow for large VMs
- Alert on quota violations

---

### 5. **Storage Quotas and Disk Space Management** ⚠️ IMPORTANT

**Risk:** Operator fills up disk with VMs, ISOs, or snapshots.

**Current State:** ⚠️ No quotas on /var/lib/hypervisor

**Recommendation:**
```nix
# Filesystem quotas
services.quota = {
  enable = true;
};

# Separate filesystem for VM storage with quota
fileSystems."/var/lib/hypervisor" = {
  device = "/dev/vg/hypervisor";
  fsType = "ext4";
  options = [ "usrquota" "grpquota" ];
};

# Set quota for operator
systemd.tmpfiles.rules = [
  # Limit operator to 500GB
  "q /var/lib/hypervisor - hypervisor-operator libvirtd 500G"
];
```

**Additional Measures:**
- Automated cleanup of old snapshots
- Warning at 80% usage
- Prevent operations at 95% usage
- Regular disk usage reporting

---

### 6. **Snapshot Lifecycle Management** ⚠️ IMPORTANT

**Risk:** Snapshot sprawl - old snapshots consume disk space and create confusion.

**Current State:** ⚠️ Operator can create unlimited snapshots

**Recommendation:**
```bash
# Snapshot policy
MAX_SNAPSHOTS_PER_VM=10
MAX_SNAPSHOT_AGE_DAYS=30

# Automated cleanup script
#!/usr/bin/env bash
for vm in $(virsh list --all --name); do
  # Count snapshots
  snap_count=$(virsh snapshot-list "$vm" --name | wc -l)
  
  if [ "$snap_count" -gt "$MAX_SNAPSHOTS_PER_VM" ]; then
    echo "WARNING: $vm has $snap_count snapshots (max $MAX_SNAPSHOTS_PER_VM)"
    # Delete oldest snapshots (requires admin)
  fi
done
```

**Best Practices:**
- Name snapshots with timestamp and purpose
- Automatic deletion after 30 days
- Keep only last N snapshots
- Require description for snapshots

---

### 7. **Network Isolation and Security Zones** 🔒 CRITICAL

**Risk:** VMs in different security zones can communicate (DMZ ↔ Internal).

**Current State:** ⚠️ Network isolation not enforced by default

**Recommendation:**
```nix
# Network security zones
networking.firewall.extraCommands = ''
  # Prevent DMZ VMs from accessing internal network
  iptables -I FORWARD -i br-dmz -o br-internal -j DROP
  iptables -I FORWARD -i br-dmz -o br-management -j DROP
  
  # Allow only specific ports from DMZ to services
  iptables -A FORWARD -i br-dmz -o br-internal -p tcp --dport 443 -j ACCEPT
'';

# Libvirt network isolation
virtualisation.libvirtd.extraConfig = ''
  # Enable network filtering
  nwfilter_enable = 1
'';
```

**Implementation:**
- Separate bridges for each security zone
- Firewall rules between zones
- Network policies in VM profiles
- Regular network traffic auditing

---

### 8. **VM Escape Prevention** 🔒 CRITICAL

**Risk:** Attacker compromises a VM and escapes to host system.

**Current State:** ✅ Partially mitigated (AppArmor, seccomp, namespaces)

**Additional Hardening:**
```nix
# Enhanced VM isolation
virtualisation.libvirtd.qemu.verbatimConfig = ''
  # Disable unnecessary QEMU features
  vnc_allow_host_audio = 0
  
  # Stricter sandboxing
  security_require_elevated = 1
'';

# SELinux/AppArmor for VMs
security.apparmor.policies = {
  "libvirt-qemu" = {
    profile = ''
      # Restrict VM process capabilities
      deny /proc/sys/** w,
      deny /sys/** w,
      deny /dev/mem r,
      deny /dev/kmem r,
    '';
  };
};

# Seccomp filter
boot.kernelParams = [ "vsyscall=none" ];

# Disable nested virtualization (if not needed)
boot.extraModprobeConfig = ''
  options kvm_intel nested=0
  options kvm_amd nested=0
'';
```

**Best Practices:**
- Run VMs as non-root
- Disable unused QEMU features
- Use SEV/TDX for confidential computing
- Regular security updates
- Vulnerability scanning of VM images

---

### 9. **VM Clone Operations** ⚠️ PRIVILEGED?

**Risk:** Cloning VMs can bypass licensing, duplicate sensitive data, or create identical credentials.

**Current State:** ⚠️ Not explicitly handled

**Decision Needed:** Should operator be able to clone VMs?

**Option A: Allow cloning (convenience)**
- Faster VM deployment
- Template-based workflows
- Risk: Credential duplication, license violations

**Option B: Restrict cloning (security)**
- Requires admin approval
- Prevents credential duplication
- Enforces proper provisioning

**Recommendation:** 
- Allow cloning from approved templates only
- Require admin approval for cloning existing VMs
- Automatic credential reset on clone

```nix
security.polkit.extraConfig = ''
  // Cloning requires admin approval
  polkit.addRule(function(action, subject) {
    if (action.id == "org.libvirt.unix.manage") {
      var cmd = action.lookup("command_line");
      if (cmd && cmd.indexOf("clone") >= 0) {
        if (subject.isInGroup("wheel")) {
          return polkit.Result.AUTH_ADMIN;
        }
        return polkit.Result.NO;
      }
    }
  });
'';
```

---

### 10. **Guest Agent Security** ⚠️ IMPORTANT

**Risk:** QEMU guest agent provides host↔guest communication channel that could be exploited.

**Current State:** ⚠️ Not explicitly restricted

**Recommendation:**
```nix
# Restrict guest agent capabilities
virtualisation.libvirtd.qemu.verbatimConfig = ''
  # Disable dangerous guest agent commands
  seccomp_sandbox = 1
'';
```

**Guest Agent Risks:**
- File system access from host to guest
- Command execution in guest
- Password injection
- Could be exploited if guest is compromised

**Best Practice:**
- Enable only if needed
- Use for monitoring only (read-only)
- Disable file transfer and exec features
- Regular updates

---

### 11. **USB and PCI Device Passthrough** 🔒 PRIVILEGED

**Risk:** Passing through USB/PCI devices can:
- Bypass VM isolation
- Provide DMA access to host memory
- Introduce malicious hardware

**Current State:** ⚠️ Should be admin-only

**Recommendation:**
```nix
# USB/PCI passthrough is ADMIN-ONLY
# Operator cannot attach host devices

# Rationale:
# - Security risk (DMA attacks)
# - Resource contention
# - Hardware compatibility issues
# - Potential for host compromise
```

**If passthrough needed:**
- Require explicit approval
- Use IOMMU groups properly
- Whitelist allowed devices
- Audit all passthrough operations

---

### 12. **VM Console Session Recording** 📊 COMPLIANCE

**Risk:** No audit trail of what operators do inside VM consoles.

**Current State:** ❌ Not implemented

**Recommendation:**
```nix
# Record all console sessions for audit
systemd.services.console-recorder = {
  description = "VM Console Session Recorder";
  script = ''
    # Wrap virsh console with script command
    # Records all input/output
    script -f /var/log/hypervisor/console-$(date +%Y%m%d-%H%M%S).log \
           virsh console "$VM_NAME"
  '';
};
```

**Compliance Requirements:**
- PCI-DSS: Log all administrative access
- HIPAA: Audit trail required
- SOC2: Access logging

**Implementation:**
- Log all console connections
- Include timestamp, user, VM name
- Encrypt logs
- Retention policy (90+ days)

---

### 13. **Centralized Logging and SIEM Integration** 📊 COMPLIANCE

**Risk:** Logs only on local system, no central monitoring, difficult to detect attacks.

**Current State:** ⚠️ Local auditd only

**Recommendation:**
```nix
# Centralized syslog
services.rsyslog = {
  enable = true;
  extraConfig = ''
    # Forward to SIEM
    *.* @@siem.example.com:514
    
    # TLS encryption for log transmission
    $DefaultNetstreamDriver gtls
    $ActionSendStreamDriverMode 1
    $ActionSendStreamDriverAuthMode anon
  '';
};

# Or use journald remote
services.journald.extraConfig = ''
  ForwardToSyslog=yes
'';
```

**SIEM Integration:**
- Send audit logs to central SIEM
- Alert on suspicious activities
- Correlation with other systems
- Compliance reporting

**Key Events to Monitor:**
- VM creation/deletion
- Failed authentication attempts
- Privilege escalation attempts
- Resource quota violations
- Unusual network traffic

---

### 14. **VM Metadata and Change Tracking** 📊 COMPLIANCE

**Risk:** No record of who created VM, when, why, or what's changed.

**Current State:** ⚠️ Basic audit logs only

**Recommendation:**
```json
// Enhanced VM profile with metadata
{
  "name": "web-server-01",
  "metadata": {
    "created_by": "operator-alice",
    "created_at": "2025-10-11T10:30:00Z",
    "purpose": "Production web server",
    "ticket": "JIRA-1234",
    "approved_by": "admin-bob",
    "cost_center": "Engineering",
    "environment": "production",
    "compliance_level": "pci-dss",
    "data_classification": "confidential"
  }
}
```

**Benefits:**
- Audit trail for compliance
- Cost allocation
- Capacity planning
- Security classification
- Change management

---

### 15. **Multi-Factor Authentication (MFA)** 🔒 CRITICAL

**Risk:** Password-only authentication for admin access.

**Current State:** ❌ Not implemented

**Recommendation:**
```nix
# Enable MFA for admin access
security.pam.services.sudo.googleAuthenticator = {
  enable = true;
};

security.pam.services.sshd.googleAuthenticator = {
  enable = true;
};

# Or use hardware tokens (YubiKey)
security.pam.u2f.enable = true;
```

**Compliance:** Required for most compliance frameworks

---

### 16. **Emergency Procedures and Break-Glass Access** 🔒 CRITICAL

**Risk:** System locked down so tight that emergency access is impossible.

**Current State:** ⚠️ Not documented

**Recommendation:**
```nix
# Emergency admin account (stored offline)
users.users.emergency = {
  isSystemUser = true;
  extraGroups = [ "wheel" ];
  # Password stored in sealed envelope
  hashedPassword = "$6$...";
};

# Emergency console access
boot.kernelParams = [ "systemd.debug-shell" ];

# Break-glass procedure documented
# 1. Boot to single-user mode
# 2. Use emergency account
# 3. Log all actions
# 4. Report to security team
```

**Documentation Required:**
- Emergency contact procedures
- Root password recovery
- System recovery procedures
- Escalation paths

---

### 17. **Rate Limiting and DoS Prevention** ⚠️ IMPORTANT

**Risk:** Operator creates too many VMs rapidly, causing system instability.

**Current State:** ❌ Not implemented

**Recommendation:**
```bash
# Rate limiting script
#!/usr/bin/env bash
RATE_LIMIT_FILE="/var/lib/hypervisor/rate-limit-$USER"
MAX_VMS_PER_HOUR=10

# Check rate limit
count=$(find "$RATE_LIMIT_FILE" -mmin -60 -type f | wc -l)
if [ "$count" -ge "$MAX_VMS_PER_HOUR" ]; then
  echo "Rate limit exceeded: $count VMs created in last hour"
  exit 1
fi

# Record creation
date >> "$RATE_LIMIT_FILE"
```

---

### 18. **VM Template Management** ⚠️ IMPORTANT

**Risk:** Templates can be modified to include backdoors or vulnerabilities.

**Current State:** ⚠️ Not implemented

**Recommendation:**
```nix
# Immutable templates
systemd.tmpfiles.rules = [
  # Template directory is read-only for operators
  "d /var/lib/hypervisor/templates 0750 root root - -"
  "Z /var/lib/hypervisor/templates 0440 root root - -"
];

# Only admins can modify templates
# Operator can only clone from templates
```

**Best Practices:**
- Regular template updates
- Security scanning of templates
- Version control for templates
- Approval process for new templates

---

### 19. **Disaster Recovery and Business Continuity** 📋 PLANNING

**Current State:** ⚠️ Not documented

**Required Documentation:**
- Recovery Time Objective (RTO)
- Recovery Point Objective (RPO)
- Backup procedures
- Restore procedures
- Failover procedures
- Testing schedule

---

### 20. **Compliance Framework Mapping** 📋 COMPLIANCE

Map security controls to compliance requirements:

**PCI-DSS Requirements:**
- ✅ Requirement 8: User authentication (MFA needed)
- ✅ Requirement 10: Logging and monitoring
- ⚠️ Requirement 3: Data encryption (VM disks)
- ⚠️ Requirement 2: Secure configurations

**HIPAA Requirements:**
- ⚠️ §164.312(a)(1): Access Control
- ✅ §164.312(b): Audit Controls
- ⚠️ §164.312(e)(1): Transmission Security

**SOC2 Requirements:**
- ✅ CC6.1: Logical access controls
- ✅ CC7.2: System monitoring
- ⚠️ CC6.6: Encryption

---

## Priority Matrix

| Item | Priority | Effort | Compliance | Risk |
|------|----------|--------|------------|------|
| VM Disk Encryption | 🔴 HIGH | High | Yes | Critical |
| MFA for Admins | 🔴 HIGH | Medium | Yes | High |
| Backup Encryption | 🔴 HIGH | Low | Yes | High |
| Resource Quotas | 🟡 MEDIUM | Medium | No | Medium |
| Snapshot Lifecycle | 🟡 MEDIUM | Low | No | Medium |
| Network Isolation | 🔴 HIGH | Medium | Depends | High |
| SIEM Integration | 🟡 MEDIUM | High | Yes | Medium |
| Console Recording | 🟡 MEDIUM | Low | Yes | Medium |
| Rate Limiting | 🟢 LOW | Low | No | Low |
| VM Metadata | 🟡 MEDIUM | Low | Yes | Medium |

---

## Recommended Implementation Order

### Phase 1: Critical Security (Week 1)
1. ✅ Deploy production security config (already done)
2. 🔒 Enable VM disk encryption
3. 🔒 Configure MFA for admin access
4. 🔒 Implement backup encryption

### Phase 2: Operational Security (Week 2)
5. 📊 Configure centralized logging/SIEM
6. 🔒 Implement network isolation
7. ⚠️ Set up resource quotas
8. 📋 Document emergency procedures

### Phase 3: Compliance & Audit (Week 3)
9. 📊 Enable console session recording
10. 📋 Implement VM metadata tracking
11. 📋 Create compliance documentation
12. 📊 Set up monitoring dashboards

### Phase 4: Operational Excellence (Week 4)
13. ⚠️ Snapshot lifecycle management
14. ⚠️ Template management system
15. ⚠️ Rate limiting
16. 📋 Disaster recovery testing

---

## Summary

**You have a strong foundation!** The production security config covers the basics well. The main gaps are:

### Must-Have (Compliance):
- ✅ VM disk encryption
- ✅ MFA for admins
- ✅ Backup encryption
- ✅ Centralized logging

### Should-Have (Operations):
- ✅ Resource quotas
- ✅ Network isolation
- ✅ Snapshot management
- ✅ Emergency procedures

### Nice-to-Have (Enhancements):
- Console recording
- Rate limiting
- VM metadata
- Template management

The configuration you have is production-ready for **medium-security environments**. For **high-security/compliance**, implement the "Must-Have" items above.
