# Hypervisor Suite - Development Roadmap

**Based on Audit Report 2025-10-11**

This roadmap prioritizes improvements based on impact, effort, and alignment with design goals (new-user-friendly, secure, minimal overhead).

---

## Phase 1: Critical Fixes (Week 1) 🔴

**Effort:** 2-3 hours  
**Impact:** High - Fixes broken functionality and security issues

### 1.1 Fix Setup Wizard (CRITICAL)
- **File:** `scripts/setup_wizard.sh` lines 64-78
- **Issue:** Generates invalid Nix configuration
- **Time:** 15 minutes
- **Priority:** P0 (blocking)

**Implementation:**
```bash
# Replace broken string interpolation with proper bash conditional
cat > /etc/hypervisor/configuration/security-local.nix <<NIX
{ config, lib, pkgs, ... }:
{
  hypervisor.security.strictFirewall = $( [[ $sf == 1 ]] && echo true || echo false );
  hypervisor.security.migrationTcp = $( [[ $mt == 1 ]] && echo true || echo false );
}
NIX
```

### 1.2 Fix Password Input Security
- **File:** `scripts/iso_manager.sh`
- **Issue:** Passwords may leak in process list
- **Time:** 20 minutes
- **Priority:** P0 (security)

**Implementation:** Use temporary file in /dev/shm with restrictive permissions

### 1.3 Add VM Name Validation
- **File:** `scripts/json_to_libvirt_xml_and_define.sh`
- **Issue:** Insufficient input validation
- **Time:** 30 minutes
- **Priority:** P1 (security/stability)

**Implementation:** Strict regex validation with clear error messages

### 1.4 Add Log Rotation
- **File:** `configuration/configuration.nix`
- **Issue:** Logs can grow unbounded
- **Time:** 10 minutes
- **Priority:** P1 (maintenance)

**Implementation:** Enable logrotate service with weekly rotation

---

## Phase 2: Documentation Overhaul (Weeks 2-3) 📚

**Effort:** 20-30 hours  
**Impact:** Very High - Directly addresses new user needs

### 2.1 Expand Quick Start Guide (Week 2)
- **File:** `docs/quickstart.txt` → `docs/quickstart_expanded.md`
- **Content:** 200+ line step-by-step guide with troubleshooting
- **Time:** 4-6 hours
- **Priority:** P0 (new users)

**Deliverables:**
- [ ] Step-by-step installation with expected output
- [ ] Screenshots or ASCII diagrams for each step
- [ ] Common issues section with specific fixes
- [ ] Next steps and learning resources

### 2.2 Create Troubleshooting Guide (Week 2)
- **File:** `docs/troubleshooting.md`
- **Content:** Decision trees for common problems
- **Time:** 4-6 hours
- **Priority:** P0 (new users)

**Deliverables:**
- [ ] VM won't start (5+ scenarios)
- [ ] Network issues (bridge, DHCP, firewall)
- [ ] Console access problems
- [ ] Performance issues
- [ ] Disk/storage problems

### 2.3 Add Architecture Documentation (Week 2-3)
- **File:** `docs/architecture/`
- **Content:** System design with diagrams
- **Time:** 6-8 hours
- **Priority:** P1 (understanding)

**Deliverables:**
- [ ] System overview diagram
- [ ] Security architecture (layers of defense)
- [ ] Network architecture (bridges, zones, firewall)
- [ ] Storage architecture
- [ ] Boot process flow

### 2.4 Create VM Recipe Cookbook (Week 3)
- **File:** `docs/recipes/`
- **Content:** Ready-to-use VM configurations
- **Time:** 4-6 hours
- **Priority:** P1 (usability)

**Deliverables:**
- [ ] Windows 11 Gaming VM with GPU passthrough
- [ ] Ubuntu Server with Cloud-Init
- [ ] Secure Isolated Test Environment
- [ ] Multi-VM Development Lab
- [ ] High-Performance Computing VM

### 2.5 Write FAQ (Week 3)
- **File:** `docs/FAQ.md`
- **Content:** 30+ common questions
- **Time:** 2-3 hours
- **Priority:** P2 (reference)

---

## Phase 3: User Experience Improvements (Weeks 4-6) 🎨

**Effort:** 30-40 hours  
**Impact:** High - Improves day-to-day usability

### 3.1 Implement Diagnostic Tool (Week 4)
- **File:** `scripts/diagnose.sh`
- **Features:** Comprehensive system health check
- **Time:** 4-6 hours
- **Priority:** P0 (troubleshooting)

**Deliverables:**
- [ ] Check KVM, IOMMU, libvirt status
- [ ] Verify storage space and disk health
- [ ] Test network bridges and connectivity
- [ ] List VMs with resource usage
- [ ] Show recent errors from logs
- [ ] Provide actionable recommendations

### 3.2 Improve Error Messages (Week 4-5)
- **Files:** All `scripts/*.sh`
- **Pattern:** Error + Reason + How to Fix
- **Time:** 8-12 hours
- **Priority:** P0 (new users)

**Approach:**
1. Audit all error messages in scripts
2. Add context (what failed, why)
3. Suggest specific fix commands
4. Point to relevant documentation

### 3.3 Add VM Dashboard View (Week 5)
- **File:** `scripts/dashboard.sh` or integrate into `menu.sh`
- **Features:** Real-time VM status overview
- **Time:** 6-8 hours
- **Priority:** P1 (operations)

**Deliverables:**
- [ ] List all VMs with status (running/stopped)
- [ ] Show resource usage (CPU, RAM, disk)
- [ ] Network connectivity indicator
- [ ] Quick actions (start/stop/console)
- [ ] Auto-refresh every N seconds

### 3.4 Create Console Launcher (Week 5-6)
- **File:** `scripts/menu.sh` + helper functions
- **Features:** One-click SPICE/VNC access from TUI
- **Time:** 4-6 hours
- **Priority:** P1 (usability)

**Deliverables:**
- [ ] Detect available viewers (remote-viewer, vncviewer)
- [ ] Launch viewer automatically
- [ ] Handle missing viewer gracefully
- [ ] Fall back to showing connection URI

### 3.5 Add Bulk Operations (Week 6)
- **File:** `scripts/bulk_ops.sh`
- **Features:** Manage multiple VMs at once
- **Time:** 4-6 hours
- **Priority:** P2 (power users)

**Deliverables:**
- [ ] Start/stop all VMs in a group
- [ ] Snapshot multiple VMs
- [ ] Apply resource limits to group
- [ ] Generate group status report

---

## Phase 4: Testing Infrastructure (Weeks 7-10) 🧪

**Effort:** 40-60 hours  
**Impact:** High - Ensures reliability and quality

### 4.1 ShellCheck Integration (Week 7)
- **File:** `.github/workflows/shellcheck.yml`
- **Features:** Automated script linting
- **Time:** 2-3 hours
- **Priority:** P0 (quality)

**Deliverables:**
- [ ] CI workflow for ShellCheck
- [ ] Fix all ShellCheck warnings in scripts/
- [ ] Add ShellCheck badge to README
- [ ] Document exceptions if any

### 4.2 Shell Unit Tests (Week 7-8)
- **Framework:** BATS (Bash Automated Testing System)
- **Files:** `tests/unit/*.bats`
- **Time:** 12-16 hours
- **Priority:** P1 (reliability)

**Test Coverage:**
- [ ] `xml_escape()` function
- [ ] `require()` dependency check
- [ ] JSON parsing helpers
- [ ] Path validation functions
- [ ] Name sanitization

### 4.3 Rust Unit Tests (Week 8)
- **Files:** `tools/*/src/*.rs`
- **Framework:** Built-in cargo test
- **Time:** 8-12 hours
- **Priority:** P1 (reliability)

**Test Coverage:**
- [ ] XML generation in vmctl
- [ ] Escape functions
- [ ] Profile parsing
- [ ] ISO download in isoctl

### 4.4 Integration Tests (Week 9-10)
- **Files:** `tests/integration/*.sh`
- **Features:** End-to-end workflows
- **Time:** 16-24 hours
- **Priority:** P1 (reliability)

**Test Scenarios:**
- [ ] Bootstrap fresh NixOS system
- [ ] Download and verify ISO
- [ ] Create VM from profile
- [ ] Start VM successfully
- [ ] Access console
- [ ] Stop VM gracefully
- [ ] Delete VM completely
- [ ] Network connectivity
- [ ] Snapshot/restore

### 4.5 CI/CD Pipeline (Week 10)
- **File:** `.github/workflows/ci.yml`
- **Features:** Automated build and test
- **Time:** 4-6 hours
- **Priority:** P1 (automation)

**Workflow Steps:**
1. ShellCheck all scripts
2. Build NixOS configuration
3. Build bootable ISO
4. Run Rust tests
5. Run integration tests (if KVM available)
6. Upload artifacts

---

## Phase 5: Monitoring & Observability (Weeks 11-14) 📊

**Effort:** 40-50 hours  
**Impact:** High - Operational visibility

### 5.1 Complete Prometheus Exporter (Week 11-12)
- **File:** `scripts/prom_exporter.sh`
- **Features:** Real metrics collection
- **Time:** 12-16 hours
- **Priority:** P1 (operations)

**Metrics to Export:**
- [ ] Host metrics (CPU, RAM, disk, network)
- [ ] Per-VM metrics (CPU, RAM, disk I/O, network)
- [ ] Libvirt pool/volume statistics
- [ ] VM lifecycle events (start, stop, errors)
- [ ] Security events (AppArmor denials, audit events)

### 5.2 Create Grafana Dashboards (Week 12)
- **Files:** `monitoring/grafana/*.json`
- **Features:** Pre-built visualization
- **Time:** 8-12 hours
- **Priority:** P1 (operations)

**Dashboards:**
- [ ] Hypervisor Overview (all VMs at a glance)
- [ ] Per-VM Detail (deep dive into one VM)
- [ ] Host Resources (system health)
- [ ] Security Dashboard (AppArmor, audit logs)
- [ ] Network Traffic (per-VM bandwidth)

### 5.3 Implement Alerting (Week 13)
- **File:** `monitoring/alerts.yml` + integration
- **Features:** Proactive problem detection
- **Time:** 8-12 hours
- **Priority:** P2 (automation)

**Alert Rules:**
- [ ] VM stopped unexpectedly
- [ ] High CPU usage (>90% for 5m)
- [ ] High memory usage (>95%)
- [ ] Low disk space (<10% free)
- [ ] Network connectivity loss
- [ ] AppArmor denials spike

### 5.4 Structured Logging (Week 13-14)
- **Files:** All `scripts/*.sh`
- **Features:** Better log analysis
- **Time:** 8-12 hours
- **Priority:** P2 (operations)

**Implementation:**
- [ ] Standard log format: timestamp + level + component + message
- [ ] Log levels: DEBUG, INFO, WARN, ERROR, CRITICAL
- [ ] Centralized logging function
- [ ] JSON structured logs (optional)

### 5.5 Health Check Automation (Week 14)
- **File:** `scripts/health_checks.sh` enhancement
- **Features:** Continuous monitoring
- **Time:** 4-6 hours
- **Priority:** P2 (reliability)

**Deliverables:**
- [ ] Systemd timer for periodic checks
- [ ] Email/webhook notifications
- [ ] Auto-remediation for common issues
- [ ] Health score calculation

---

## Phase 6: Security Enhancements (Weeks 15-18) 🔒

**Effort:** 30-40 hours  
**Impact:** Medium-High - Defense in depth

### 6.1 Per-VM AppArmor Profiles (Week 15-16)
- **Files:** `configuration/apparmor/vm-*.profile`
- **Features:** Fine-grained VM confinement
- **Time:** 12-16 hours
- **Priority:** P1 (security)

**Implementation:**
- [ ] Template generator for VM profiles
- [ ] Per-VM disk access only
- [ ] Per-VM device access (if hostdev)
- [ ] Network isolation
- [ ] Capability restrictions

### 6.2 Secrets Management Integration (Week 16-17)
- **Files:** `modules/secrets.nix`
- **Features:** Secure credential handling
- **Time:** 8-12 hours
- **Priority:** P1 (security)

**Integration Options:**
1. sops-nix (SOPS + age encryption)
2. agenix (age-based secrets for NixOS)

**Use Cases:**
- [ ] Encrypted VM profiles with passwords
- [ ] Cloud-init user-data secrets
- [ ] TLS certificates for remote access
- [ ] API keys for external services

### 6.3 Firewall Rules Persistence (Week 17)
- **File:** `configuration/security.nix` + VM profiles
- **Features:** Declarative firewall management
- **Time:** 6-8 hours
- **Priority:** P1 (security)

**Implementation:**
- [ ] Convert per_vm_firewall.sh to nftables
- [ ] Store rules in VM profiles
- [ ] Generate nftables config from profiles
- [ ] Auto-reload on profile changes

### 6.4 ISO Checksum Enforcement (Week 17-18)
- **Files:** `scripts/json_to_libvirt_xml_and_define.sh`, `scripts/iso_manager.sh`
- **Features:** Mandatory verification
- **Time:** 4-6 hours
- **Priority:** P2 (security)

**Implementation:**
- [ ] Create `.sha256.verified` marker files
- [ ] Check marker before using ISO
- [ ] Allow bypass with env var (documented risk)
- [ ] Log all ISO usage

### 6.5 Audit Log Retention Policy (Week 18)
- **File:** `configuration/security.nix`
- **Features:** Compliance-ready logging
- **Time:** 2-3 hours
- **Priority:** P2 (compliance)

**Implementation:**
- [ ] Configure auditd retention (90 days default)
- [ ] Set up log rotation for audit logs
- [ ] Document retention policy
- [ ] Add log archival option

---

## Phase 7: Backup & Recovery (Weeks 19-22) 💾

**Effort:** 30-40 hours  
**Impact:** High - Data protection

### 7.1 Automated Backup System (Week 19-20)
- **File:** `scripts/backup_manager.sh`
- **Features:** Scheduled VM backups
- **Time:** 12-16 hours
- **Priority:** P1 (data protection)

**Deliverables:**
- [ ] Systemd timer for daily/weekly backups
- [ ] Full and incremental backup support
- [ ] Backup retention policies
- [ ] Multiple backends (local, NFS, S3)
- [ ] Progress indicators
- [ ] Email notifications on completion/failure

### 7.2 Snapshot Management (Week 20-21)
- **File:** `scripts/snapshot_manager.sh`
- **Features:** Easy snapshot workflows
- **Time:** 8-12 hours
- **Priority:** P1 (data protection)

**Deliverables:**
- [ ] Create snapshot with description
- [ ] List snapshots with sizes and dates
- [ ] Restore from snapshot
- [ ] Delete old snapshots
- [ ] Snapshot before updates (hook)

### 7.3 Backup Verification (Week 21)
- **File:** `scripts/backup_verify.sh`
- **Features:** Ensure backups are valid
- **Time:** 6-8 hours
- **Priority:** P2 (reliability)

**Checks:**
- [ ] Backup file integrity (checksums)
- [ ] QCOW2 image validity
- [ ] Decompression test
- [ ] Restore test (optional, in separate VM)

### 7.4 Disaster Recovery Guide (Week 22)
- **File:** `docs/disaster_recovery.md`
- **Content:** Step-by-step recovery procedures
- **Time:** 4-6 hours
- **Priority:** P2 (documentation)

**Scenarios:**
- [ ] Restore single VM from backup
- [ ] Restore entire hypervisor
- [ ] Migrate VMs to new hardware
- [ ] Recover from disk failure
- [ ] Boot from ISO and rebuild

---

## Phase 8: Optional Features (Months 6+) 🚀

**Effort:** Variable  
**Impact:** Medium - Nice-to-haves

### 8.1 Web UI (Optional)
- **Time:** 4-6 weeks
- **Priority:** P3 (alternative interface)
- **Technology:** Python Flask/FastAPI + Vue.js or htmx

**Features:**
- [ ] VM lifecycle management
- [ ] Resource monitoring dashboards
- [ ] Console access (noVNC integration)
- [ ] Log viewer
- [ ] User management

### 8.2 REST API (Optional)
- **Time:** 3-4 weeks
- **Priority:** P3 (automation)
- **Technology:** Python FastAPI or Rust Axum

**Endpoints:**
- [ ] `/vms` - List, create, delete VMs
- [ ] `/vms/{id}/start` - Start VM
- [ ] `/vms/{id}/stop` - Stop VM
- [ ] `/vms/{id}/console` - Get console URI
- [ ] `/vms/{id}/snapshots` - Snapshot management
- [ ] `/system/health` - System health check

### 8.3 VM Orchestration (Optional)
- **Time:** 2-3 weeks
- **Priority:** P3 (advanced)
- **Format:** YAML declarative configs

**Features:**
- [ ] Multi-VM environment definitions
- [ ] Dependency ordering (start DB before app)
- [ ] Network topology definition
- [ ] Bulk operations (start/stop all)

### 8.4 Storage Pool Management (Optional)
- **Time:** 3-4 weeks
- **Priority:** P3 (advanced)
- **Technologies:** ZFS, LVM thin provisioning

**Features:**
- [ ] ZFS dataset per VM
- [ ] Automatic snapshots
- [ ] Deduplication
- [ ] Compression
- [ ] Thin provisioning

### 8.5 Multi-Host Clustering (Future)
- **Time:** 8-12 weeks
- **Priority:** P4 (future vision)
- **Technologies:** Shared storage (Ceph/GlusterFS)

**Features:**
- [ ] Distributed VM management
- [ ] Live migration between hosts
- [ ] Load balancing
- [ ] High availability
- [ ] Centralized dashboard

---

## Success Metrics

### Phase 1 (Critical Fixes)
- ✅ All critical bugs fixed
- ✅ No security issues in setup wizard
- ✅ Clean ShellCheck run

### Phase 2 (Documentation)
- ✅ Quick start guide > 200 lines
- ✅ Troubleshooting covers 20+ scenarios
- ✅ 5+ VM recipes available
- 📊 User feedback: "Easy to get started" > 80%

### Phase 3 (UX)
- ✅ Diagnostic tool catches 10+ common issues
- ✅ Error messages include fix suggestions
- ✅ Dashboard shows real-time VM status
- 📊 User feedback: "Easy to use daily" > 75%

### Phase 4 (Testing)
- ✅ 100% ShellCheck pass rate
- ✅ >80% shell function test coverage
- ✅ 100% Rust test pass rate
- ✅ 10+ integration test scenarios
- ✅ CI runs on every commit

### Phase 5 (Monitoring)
- ✅ Prometheus exporter with 50+ metrics
- ✅ 5+ Grafana dashboards
- ✅ 10+ alert rules configured
- 📊 Alert noise < 5% false positive rate

### Phase 6 (Security)
- ✅ Per-VM AppArmor profiles
- ✅ All secrets encrypted at rest
- ✅ Firewall rules persist across reboots
- ✅ ISO verification mandatory
- 📊 Zero security incidents

### Phase 7 (Backup)
- ✅ Automated daily backups
- ✅ Verified backup success rate > 99%
- ✅ Restore time < 10 minutes
- 📊 Zero data loss incidents

---

## Resource Allocation

**Minimum Team:**
- 1 developer (full-time equivalent)
- Part-time docs writer (phases 2, 7.4)
- Part-time security reviewer (phase 6)

**Recommended Team:**
- 1-2 developers
- 1 technical writer
- 1 QA/testing engineer
- 1 security consultant (advisory)

**Tools & Infrastructure:**
- GitHub (source control, issues, CI/CD)
- NixOS test machines (bare metal + VMs)
- Grafana Cloud or self-hosted monitoring
- Documentation platform (GitHub Pages, ReadTheDocs)

---

## Risk Management

### High Risks

**Risk:** Breaking changes to existing users  
**Mitigation:** 
- Maintain backward compatibility
- Version profile schema
- Migration guides for major changes
- Test on multiple NixOS versions

**Risk:** Security regression  
**Mitigation:**
- Security review before releases
- Automated security scanning (CI)
- Regular updates to dependencies
- CVE monitoring

**Risk:** Performance degradation  
**Mitigation:**
- Benchmark critical paths
- Performance tests in CI
- Monitor resource usage
- Profile before/after changes

### Medium Risks

**Risk:** Documentation drift  
**Mitigation:**
- Docs update checklist in PR template
- Automated doc generation where possible
- Quarterly doc review

**Risk:** Test maintenance burden  
**Mitigation:**
- Start with critical paths
- Prioritize integration over unit tests
- Use test fixtures for common setups
- Mock external dependencies

---

## Review & Adjustment

**Monthly Reviews:**
- Progress against roadmap
- User feedback collection
- Priority adjustments
- Resource reallocation

**Quarterly Goals:**
- Q1 2026: Phases 1-3 complete
- Q2 2026: Phases 4-5 complete
- Q3 2026: Phases 6-7 complete
- Q4 2026: Phase 8 features as desired

---

## Conclusion

This roadmap balances immediate needs (critical fixes), user experience improvements (documentation, UX), and long-term reliability (testing, monitoring, backups).

**Start Here:**
1. Week 1: Fix critical bugs (2-3 hours)
2. Weeks 2-3: Documentation overhaul (20-30 hours)
3. Weeks 4-6: UX improvements (30-40 hours)

After the first 6 weeks, you'll have:
- ✅ A rock-solid, bug-free system
- ✅ Comprehensive documentation for new users
- ✅ Greatly improved daily usability
- ✅ Clear path forward for testing and monitoring

**Adjust as needed based on:**
- User feedback and pain points
- Available resources
- Emerging priorities
- Community contributions

This is a living document—update it as you progress and learn!
