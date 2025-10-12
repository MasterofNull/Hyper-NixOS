# Security Implementation Checklist

Quick reference for implementing production security model.

---

## ✅ What You Have (Already Implemented)

### Access Control
- ✅ Dedicated operator user (no sudo)
- ✅ Polkit for VM management
- ✅ Granular permissions (create/start/stop allowed, delete restricted)
- ✅ Menu auto-restart (prevents shell escape)
- ✅ Systemd hardening (NoNewPrivileges, ProtectSystem, etc.)
- ✅ Audit logging (auditd enabled)
- ✅ SSH key-only authentication
- ✅ Password required for admin operations

### VM Operations
- ✅ Operator can create VMs
- ✅ Operator can start/stop/restart VMs
- ✅ Operator can access VM console
- ✅ Operator can download ISOs and GPG keys
- ✅ Operator can create snapshots
- ✅ Destructive operations (delete) require admin

### Network
- ✅ Firewall enabled
- ✅ SSH hardened
- ✅ Fail2ban configured

---

## ⚠️ Critical Gaps (Implement ASAP)

### 1. VM Disk Encryption
**Status:** ❌ Not implemented  
**Risk:** HIGH - VM disks contain sensitive data  
**Effort:** Medium  
**Priority:** 🔴 CRITICAL

**Quick Fix:**
```bash
# Create encrypted VM disk
qemu-img create -f luks vm-disk.qcow2 20G

# Or use LUKS at host level
cryptsetup luksFormat /dev/vg/vm-storage
```

### 2. Multi-Factor Authentication
**Status:** ❌ Not implemented  
**Risk:** HIGH - Password-only admin access  
**Effort:** Medium  
**Priority:** 🔴 CRITICAL

**Quick Fix:**
```nix
# Add to configuration
security.pam.services.sudo.googleAuthenticator.enable = true;
security.pam.services.sshd.googleAuthenticator.enable = true;
```

### 3. Backup Encryption
**Status:** ❌ Not implemented  
**Risk:** HIGH - Backups contain full VM state  
**Effort:** Low  
**Priority:** 🔴 CRITICAL

**Quick Fix:**
```bash
# Encrypt backups
gpg --encrypt --recipient admin@example.com vm-backup.qcow2
```

### 4. Centralized Logging
**Status:** ⚠️ Local only  
**Risk:** MEDIUM - Can't detect distributed attacks  
**Effort:** High  
**Priority:** 🟡 HIGH

**Quick Fix:**
```nix
services.rsyslog = {
  enable = true;
  extraConfig = ''
    *.* @@siem-server:514
  '';
};
```

---

## ⚠️ Important Gaps (Implement Soon)

### 5. Resource Quotas
**Status:** ❌ Not implemented  
**Risk:** MEDIUM - Operator could cause DoS  
**Effort:** Medium  
**Priority:** 🟡 HIGH

**Implementation:**
- Limit max VMs per operator: 20
- Limit max CPU allocation: 80%
- Limit max memory: 128GB
- Limit max disk per VM: 500GB
- Enforce before VM creation

### 6. Network Isolation
**Status:** ⚠️ Single bridge  
**Risk:** MEDIUM - No security zones  
**Effort:** Medium  
**Priority:** 🟡 HIGH

**Implementation:**
- Separate bridges: br-dmz, br-internal, br-management
- Firewall rules between zones
- Prevent DMZ ↔ Internal communication

### 7. Snapshot Lifecycle
**Status:** ❌ Not implemented  
**Risk:** LOW - Snapshot sprawl  
**Effort:** Low  
**Priority:** 🟢 MEDIUM

**Implementation:**
- Max 10 snapshots per VM
- Auto-delete after 30 days
- Require description for snapshots

### 8. Storage Quotas
**Status:** ❌ Not implemented  
**Risk:** MEDIUM - Disk space exhaustion  
**Effort:** Low  
**Priority:** 🟡 MEDIUM

**Quick Fix:**
```nix
systemd.tmpfiles.rules = [
  "q /var/lib/hypervisor - hypervisor-operator libvirtd 500G"
];
```

---

## 🟢 Nice to Have (Future Enhancements)

### 9. Console Session Recording
**Priority:** 🟢 MEDIUM (Compliance requirement)

### 10. Rate Limiting
**Priority:** 🟢 LOW

### 11. VM Metadata Tracking
**Priority:** 🟢 MEDIUM (Compliance requirement)

### 12. VM Template Management
**Priority:** 🟢 MEDIUM

---

## 🚀 Quick Start: Implement Security-Production Config

### Step 1: Copy Production Security Config
```bash
# The config is already created
sudo cp configuration/security-production.nix \
        /var/lib/hypervisor/configuration/security-production.nix
```

### Step 2: Import in Configuration
Edit `/etc/hypervisor/src/configuration/configuration.nix`:
```nix
imports = [
  # ... existing imports ...
  /var/lib/hypervisor/configuration/security-production.nix
];
```

### Step 3: Create Admin User
```bash
# Add your admin user
sudo useradd -m -G wheel -s /bin/bash admin
sudo passwd admin
```

### Step 4: Configure SSH Keys
```bash
# Copy your SSH key
sudo mkdir -p /home/admin/.ssh
sudo cp ~/.ssh/authorized_keys /home/admin/.ssh/
sudo chown -R admin:admin /home/admin/.ssh
sudo chmod 700 /home/admin/.ssh
sudo chmod 600 /home/admin/.ssh/authorized_keys
```

### Step 5: Rebuild System
```bash
# Rebuild with new security config
sudo nixos-rebuild switch --flake "/etc/hypervisor#$(hostname -s)"
```

### Step 6: Test Operator Access
```bash
# System will reboot with autologin to hypervisor-operator
# Test that:
# 1. Console menu appears
# 2. Can create VMs (no sudo needed)
# 3. Can start/stop VMs
# 4. Can download ISOs
# 5. Cannot delete VMs (requires admin)
# 6. Cannot sudo without password
```

### Step 7: Test Admin Access
```bash
# From another terminal or SSH
ssh admin@hypervisor-host

# Test that:
# 1. SSH works with keys
# 2. Can sudo (with password)
# 3. Can delete VMs
# 4. Can modify system config
```

---

## 📋 Compliance Checklist

### PCI-DSS Requirements
- [ ] VM disk encryption (Requirement 3)
- [ ] Access controls (Requirement 7)
- [ ] MFA for admins (Requirement 8)
- [ ] Logging and monitoring (Requirement 10)
- [ ] Regular security testing (Requirement 11)

### HIPAA Requirements
- [ ] Access control (§164.312(a)(1))
- [ ] Audit controls (§164.312(b))
- [ ] Encryption (§164.312(e)(1))
- [ ] Person authentication (§164.312(d))

### SOC2 Requirements
- [ ] Logical access controls (CC6.1)
- [ ] System monitoring (CC7.2)
- [ ] Encryption (CC6.6)
- [ ] Change management (CC8.1)

---

## 🎯 30-Day Implementation Plan

### Week 1: Critical Security
**Goal:** Close critical security gaps

- [ ] Day 1-2: Deploy security-production.nix
- [ ] Day 3-4: Implement VM disk encryption
- [ ] Day 5: Configure MFA for admins
- [ ] Day 6: Set up backup encryption
- [ ] Day 7: Test and document

### Week 2: Operational Security
**Goal:** Prevent operational issues

- [ ] Day 8-9: Configure centralized logging
- [ ] Day 10-11: Implement network isolation
- [ ] Day 12-13: Set up resource quotas
- [ ] Day 14: Document emergency procedures

### Week 3: Compliance & Monitoring
**Goal:** Meet compliance requirements

- [ ] Day 15-16: Enable console recording
- [ ] Day 17-18: Implement VM metadata tracking
- [ ] Day 19-20: Create compliance documentation
- [ ] Day 21: Set up monitoring dashboards

### Week 4: Testing & Validation
**Goal:** Ensure everything works

- [ ] Day 22-23: Security testing
- [ ] Day 24-25: Penetration testing
- [ ] Day 26-27: Disaster recovery testing
- [ ] Day 28-30: Documentation and training

---

## 🔍 Testing Procedures

### Security Testing
```bash
# Test 1: Operator cannot sudo
su - hypervisor-operator
sudo ls  # Should ask for password
sudo -l  # Should show no sudo privileges

# Test 2: Operator can manage VMs
virsh list --all  # Should work
virsh start vm-name  # Should work
virsh shutdown vm-name  # Should work

# Test 3: Operator cannot delete VMs
virsh undefine vm-name  # Should be denied by polkit

# Test 4: Menu restart on exit
# Exit menu (Ctrl+C) - menu should restart immediately

# Test 5: Admin can delete VMs
su - admin
sudo virsh undefine vm-name  # Should work after password
```

### Penetration Testing
- [ ] Attempt privilege escalation from operator
- [ ] Test VM escape scenarios
- [ ] Verify network isolation
- [ ] Test rate limiting
- [ ] Verify audit logging
- [ ] Test backup encryption
- [ ] Verify MFA enforcement

---

## 📝 Documentation Required

### Security Documentation
- [ ] Security policy document
- [ ] Risk assessment
- [ ] Threat model
- [ ] Incident response plan
- [ ] Disaster recovery plan

### Operational Documentation
- [ ] User guide for operators
- [ ] Admin guide
- [ ] Emergency procedures
- [ ] Backup/restore procedures
- [ ] Monitoring runbooks

### Compliance Documentation
- [ ] Control matrix (map controls to requirements)
- [ ] Audit trail procedures
- [ ] Change management policy
- [ ] Access control policy
- [ ] Data retention policy

---

## 🚨 Red Flags to Watch For

### Operator Behavior
- Multiple failed sudo attempts
- Attempts to modify system files
- Unusual VM creation patterns
- Large resource allocations
- Snapshot sprawl

### System Health
- Disk space >90%
- CPU >80% sustained
- Memory exhaustion
- Network saturation
- Failed audit logging

### Security Events
- Failed authentication attempts
- Privilege escalation attempts
- Unusual network traffic from VMs
- VM console access at odd hours
- Configuration changes without tickets

---

## ✅ Success Criteria

You've successfully implemented production security when:

1. ✅ Operator can perform daily tasks without sudo
2. ✅ Destructive operations require admin approval
3. ✅ All actions are logged and auditable
4. ✅ Physical access doesn't grant full system access
5. ✅ VMs are encrypted at rest
6. ✅ Backups are encrypted
7. ✅ Network zones are isolated
8. ✅ Resource limits prevent DoS
9. ✅ Emergency procedures are documented
10. ✅ Compliance requirements are met

---

## 📞 Support and Resources

- **Security Model:** `docs/SECURITY_MODEL.md`
- **Considerations:** `docs/SECURITY_CONSIDERATIONS.md`
- **Production Config:** `configuration/security-production.nix`
- **Network Guide:** `docs/NETWORK_CONFIGURATION.md`
- **Troubleshooting:** `docs/TROUBLESHOOTING.md`

---

**Remember:** Security is a process, not a destination. Regular reviews, updates, and testing are essential!
