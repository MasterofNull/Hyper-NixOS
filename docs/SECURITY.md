# Security Policy

## Reporting Security Vulnerabilities

**DO NOT** open public GitHub issues for security vulnerabilities.

Instead, please report security vulnerabilities privately to:
- **Email:** security@hyper-nixos.org (for serious vulnerabilities)
- **GitHub:** Use GitHub's private vulnerability reporting feature

We will acknowledge your report within 48 hours and provide a detailed response within 7 days.

## Security Model

### Threat Model

Hyper-NixOS is designed with a layered security model suitable for:

- **Home Labs**: Personal virtualization environments
- **Small Business**: Department-level VM hosts
- **Development**: Testing and development environments
- **Edge Computing**: Remote VM management scenarios

#### In Scope

We consider the following threats in our security model:

1. **Unauthorized VM Access**: Attackers attempting to access or control VMs
2. **Privilege Escalation**: Users attempting to gain unauthorized system access
3. **Network-Based Attacks**: External attackers exploiting network services
4. **Malicious VMs**: VMs attempting to escape or attack the host
5. **Data Exfiltration**: Unauthorized data access or transmission
6. **Denial of Service**: Resource exhaustion attacks

#### Out of Scope

The following are considered out of scope:

1. **Physical Access Attacks**: We assume physical security (locked server room)
2. **Supply Chain Attacks**: Compromised hardware or NixOS packages
3. **Side-Channel Attacks**: Spectre/Meltdown variants (use kernel patches)
4. **Social Engineering**: User credential phishing
5. **Insider Threats**: Malicious administrators with root access

### Attack Surfaces

#### 1. Network Services

**Exposed Services:**
- SSH (port 22) - Optional, disabled by default
- LibVirt API (port 16509) - Local only by default
- Web Dashboard (port 8080) - Optional feature
- Monitoring (Prometheus/Grafana) - Optional feature

**Mitigations:**
- Firewall enabled by default
- Services disabled unless explicitly enabled
- Strong authentication required
- Rate limiting on exposed services
- Regular security updates via NixOS

#### 2. Virtualization Layer

**Risks:**
- VM escape vulnerabilities
- Resource exhaustion by VMs
- Shared storage access

**Mitigations:**
- QEMU/KVM isolation (industry-standard hypervisor)
- CPU pinning and resource limits
- SELinux/AppArmor integration (optional)
- Regular QEMU security updates
- Nested virtualization restrictions

#### 3. User Access

**Risks:**
- Unauthorized privilege escalation
- Password exposure
- Session hijacking

**Mitigations:**
- Privilege separation (VM operations ≠ system admin)
- Polkit for fine-grained access control
- Password protection module (prevents accidental wipes)
- Sudo rules limited to specific commands
- Audit logging of privileged operations

#### 4. Configuration Management

**Risks:**
- Malicious NixOS modules
- Configuration tampering
- Secrets exposure

**Mitigations:**
- Immutable system configuration (NixOS)
- Configuration rollback capability
- Secrets stored outside git repository
- Validation before applying changes
- Automatic configuration backups

## Security Architecture

### 1. Privilege Separation

Hyper-NixOS implements a two-tier privilege model:

#### VM Operations (No Sudo Required)
- Start/Stop/Restart VMs
- View VM status and console
- Snapshot management
- VM network configuration

**Users in groups:** `libvirtd`, `hypervisor-users`

#### System Operations (Sudo Required)
- System reconfiguration (`nixos-rebuild`)
- Service management (`systemctl`)
- Network configuration changes
- User management
- Security policy changes

**Users in groups:** `wheel`, `hypervisor-admins`

### 2. Threat Detection System

Multi-layered threat detection:

1. **Signature-Based**: Known malware and attack patterns (YARA rules)
2. **Behavioral Analysis**: Anomaly detection via machine learning
3. **Network Monitoring**: Suricata IDS integration (optional)
4. **File Integrity**: System file monitoring
5. **Correlation Engine**: Multi-sensor event correlation

**Response Modes:**
- **Monitor**: Log only, no intervention
- **Interactive**: Alert admin, await decision
- **Automatic**: Execute response playbooks

### 3. Secure Defaults

Hyper-NixOS ships with secure defaults:

- ✅ Firewall enabled
- ✅ Minimal exposed services
- ✅ Strong password requirements (when passwords are used)
- ✅ Audit logging enabled
- ✅ Automatic security updates (NixOS channels)
- ✅ SELinux/AppArmor available (opt-in)
- ✅ Encrypted VM disks (opt-in)
- ✅ Secure boot compatible

## Vulnerability Response Process

### Severity Levels

We use the following severity classifications:

#### Critical (CVSS 9.0-10.0)
- Remote code execution as root
- Complete system compromise
- Data destruction capabilities
- **Response Time:** Patch within 24 hours

#### High (CVSS 7.0-8.9)
- Privilege escalation to root
- Bypass of security features
- Significant data exposure
- **Response Time:** Patch within 7 days

#### Medium (CVSS 4.0-6.9)
- Information disclosure
- Denial of service
- Limited privilege escalation
- **Response Time:** Patch within 30 days

#### Low (CVSS 0.1-3.9)
- Minor information leaks
- Cosmetic security issues
- **Response Time:** Patch in next release

### Disclosure Timeline

1. **Day 0**: Vulnerability reported privately
2. **Day 1-2**: Acknowledgment sent, investigation begins
3. **Day 3-7**: Severity assessment, patch development
4. **Day 7-30**: Patch testing and validation
5. **Day 30**: Public disclosure (coordinated with reporter)
6. **Day 30+**: Security advisory published

## Security Best Practices

### For Administrators

1. **Keep System Updated**
   ```bash
   sudo nix-channel --update
   sudo nixos-rebuild switch
   ```

2. **Enable Security Features**
   - Enable threat detection: `hypervisor.security.threatDetection.enable = true;`
   - Enable behavioral analysis: `hypervisor.security.threatDetection.enableBehavioralAnalysis = true;`
   - Set up alerting channels (email, Slack, etc.)

3. **Regular Audits**
   ```bash
   # Review security logs
   sudo journalctl -u hypervisor-threat-detector

   # Check privilege assignments
   grep -r "hypervisor-" Hyper-NixOS/configuration.nix

   # Review sudo rules
   sudo cat /etc/sudoers.d/hypervisor
   ```

4. **Backup Configurations**
   - Keep multiple generations: `boot.loader.systemd-boot.configurationLimit = 10;`
   - Store off-system backups of repository: `Hyper-NixOS/`
   - Test rollback procedures regularly

5. **Network Isolation**
   - Use separate networks for management and VM traffic
   - Enable VLANs for VM isolation
   - Restrict management interface access by IP

### For Users

1. **Use SSH Keys** (not passwords) for remote access
2. **Enable MFA** where supported
3. **Review VM Permissions** before starting untrusted VMs
4. **Monitor Resource Usage** to detect anomalies
5. **Report Suspicious Activity** to administrators

### For Developers

1. **Follow DEVELOPMENT_REFERENCE.md** patterns
2. **Never commit secrets** to the repository
3. **Validate all user inputs** in scripts
4. **Use least privilege** in module design
5. **Document security implications** of new features

## Security Contacts

- **General Security Issues:** security@hyper-nixos.org
- **GitHub Security Advisories:** Use GitHub's private reporting
- **Emergency Contact:** (For critical actively-exploited issues)

## Security Updates

Security updates are published via:

1. **GitHub Security Advisories**: https://github.com/MasterofNull/Hyper-NixOS/security/advisories
2. **NixOS Channels**: Automated security updates
3. **Mailing List**: security-announce@hyper-nixos.org (low-traffic)

## Hall of Fame

We recognize and thank security researchers who responsibly disclose vulnerabilities:

- (Your name could be here!)

## References

- **NixOS Security**: https://nixos.org/manual/nixos/stable/#sec-security
- **QEMU Security**: https://wiki.qemu.org/SecurityProcess
- **LibVirt Security**: https://libvirt.org/securityprocess.html
- **CWE Database**: https://cwe.mitre.org/
- **CVE Database**: https://cve.mitre.org/

---

**Last Updated:** 2025-10-17
**Version:** 1.0.0
