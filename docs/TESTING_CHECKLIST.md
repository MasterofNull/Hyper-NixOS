# Testing Checklist - Intelligent Defaults Implementation

**Before Production Deployment**

---

## 🔍 **Pre-Testing Setup**

### 1. System Requirements Validation
```bash
# Run validation script
./scripts/validate-system-requirements.sh

# Expected: All required dependencies present
# Fix any missing dependencies before proceeding
```

### 2. CLI Installation
```bash
# Install unified CLI
sudo ./scripts/install-hv-cli.sh

# Verify installation
hv version
hv help
```

### 3. Permissions Check
```bash
# Ensure scripts are executable
chmod +x scripts/*.sh
chmod +x scripts/lib/*.sh
chmod +x scripts/security/*.sh
chmod +x scripts/monitoring/*.sh

# Verify key files
ls -l scripts/hv
ls -l scripts/hv-intelligent-defaults
ls -l scripts/lib/system_discovery.sh
```

---

## 🧪 **Core Infrastructure Testing**

### System Discovery Library

**Test CPU Detection**:
```bash
source scripts/lib/system_discovery.sh
get_cpu_cores
get_cpu_model
check_virt_support
get_cpu_arch
```
- [ ] Returns correct core count
- [ ] Returns CPU model name
- [ ] Detects VT-x/AMD-V correctly
- [ ] Returns correct architecture (x86_64/aarch64)

**Test Memory Detection**:
```bash
get_total_ram_mb
get_available_ram_mb
calculate_recommended_ram 32768 4 2048
```
- [ ] Returns accurate total RAM
- [ ] Returns available RAM
- [ ] Calculates recommended RAM correctly (2GB per vCPU)

**Test Storage Detection**:
```bash
detect_storage_type
get_available_storage_gb /var/lib/hypervisor
recommend_disk_format "nvme"
recommend_disk_format "hdd"
```
- [ ] Detects NVMe correctly
- [ ] Detects SSD correctly
- [ ] Detects HDD correctly
- [ ] Recommends qcow2 for SSD/NVMe
- [ ] Recommends raw for HDD

**Test Network Detection**:
```bash
list_bridges
check_default_bridge
get_default_bridge
recommend_network_mode
```
- [ ] Lists existing bridges
- [ ] Checks for virbr0
- [ ] Returns appropriate default
- [ ] Recommends NAT or bridge correctly

**Test GPU Detection**:
```bash
detect_gpu
check_gpu_passthrough
```
- [ ] Detects NVIDIA/AMD/Intel correctly
- [ ] Detects no GPU correctly
- [ ] Checks IOMMU for passthrough

**Test Complete System Report**:
```bash
generate_system_report text
generate_system_report json
```
- [ ] Text report is readable
- [ ] JSON report is valid
- [ ] All sections populated

### Intelligent Defaults Generation

**Test VM Defaults**:
```bash
generate_vm_defaults linux bash
generate_vm_defaults windows json
```
- [ ] Linux defaults: 2+ vCPUs, appropriate RAM, 40GB disk
- [ ] Windows defaults: 4+ vCPUs, 8GB+ RAM, 80GB disk
- [ ] JSON format is valid
- [ ] Reasoning included

---

## 🧙 **Wizard Testing**

### 1. Discovery Tools

**hv discover**:
```bash
hv discover
```
- [ ] Shows complete system report
- [ ] CPU info correct
- [ ] Memory info correct
- [ ] Storage info correct
- [ ] Network info correct
- [ ] GPU info correct (or "none")

**hv vm-defaults**:
```bash
hv vm-defaults linux
hv vm-defaults windows
hv vm-defaults minimal
```
- [ ] Shows recommendations for each OS type
- [ ] Includes reasoning
- [ ] Values are sensible

**hv defaults-demo**:
```bash
hv defaults-demo
```
- [ ] Interactive demo runs
- [ ] Shows detection
- [ ] Explains calculations
- [ ] Reasoning is clear

### 2. VM Creation Wizard

**Test with defaults**:
```bash
hv vm-create
# Press Enter for all prompts (accept defaults)
```
- [ ] Detects hardware correctly
- [ ] Pre-fills vCPUs (25% of host)
- [ ] Pre-fills RAM (2GB per vCPU)
- [ ] Pre-fills disk format (optimal for storage)
- [ ] Shows explanatory dialogs
- [ ] VM profile created
- [ ] No errors

**Test with overrides**:
```bash
hv vm-create
# Override each default with custom values
```
- [ ] Allows custom vCPUs
- [ ] Allows custom RAM
- [ ] Allows custom disk size
- [ ] Accepts all overrides
- [ ] VM profile created

**Edge cases**:
- [ ] Low memory system (< 8GB RAM)
- [ ] Low core count (2-4 cores)
- [ ] No virtualization support
- [ ] Minimal disk space

### 3. First-Boot Wizard

**Test tier recommendation**:
```bash
hv first-boot
```
- [ ] Detects hardware
- [ ] Shows detected resources
- [ ] Recommends appropriate tier
- [ ] Explains reasoning
- [ ] "recommend" command works
- [ ] Can select other tiers
- [ ] Configuration saved

**Expected recommendations**:
- Low resources (4GB, 2 cores) → Minimal/Standard
- Medium (16GB, 4 cores) → Standard/Enhanced
- High (32GB, 8+ cores) → Enhanced/Professional
- Very high (64GB, 16+ cores, GPU) → Professional/Enterprise

### 4. Security Configuration Wizard

**Test detection**:
```bash
hv security-config
```
- [ ] Detects open ports
- [ ] Detects running services
- [ ] Checks firewall status
- [ ] Checks SSH exposure
- [ ] Calculates risk score
- [ ] Recommends appropriate level
- [ ] Explains reasoning

**Risk scenarios**:
- [ ] No firewall → High risk
- [ ] SSH exposed → Medium/High risk
- [ ] Many open ports → High risk
- [ ] Everything secured → Low risk

**Recommendation validation**:
- [ ] Standard for low risk
- [ ] Balanced for medium risk
- [ ] Enhanced for high risk
- [ ] Strict for critical risk

### 5. Network Configuration Wizard

**Test detection**:
```bash
hv network-config
```
- [ ] Detects all interfaces
- [ ] Shows IP addresses
- [ ] Shows interface state
- [ ] Detects existing bridges
- [ ] Recommends NAT or bridge
- [ ] Explains reasoning

**Scenarios**:
- [ ] Single interface → NAT
- [ ] Multiple interfaces → Bridge option
- [ ] Existing bridge → Bridge mode
- [ ] No bridges → NAT

### 6. Backup Configuration Wizard

**Test detection**:
```bash
hv backup-config
```
- [ ] Detects data size
- [ ] Detects available backup space
- [ ] Detects storage type
- [ ] Recommends schedule
- [ ] Recommends retention
- [ ] Recommends compression
- [ ] Explains reasoning

**Validation**:
- [ ] Small dataset → Frequent backups
- [ ] Large dataset → Less frequent
- [ ] Limited space → Short retention
- [ ] Ample space → Long retention
- [ ] NVMe/SSD → zstd compression
- [ ] HDD → lz4 compression

### 7. Storage Configuration Wizard

**Test detection**:
```bash
hv storage-config
```
- [ ] Detects all storage devices
- [ ] Classifies NVMe as hot tier
- [ ] Classifies SSD as warm tier
- [ ] Classifies HDD as cold tier
- [ ] Recommends tiering strategy
- [ ] Explains use cases

### 8. Monitoring Configuration Wizard

**Test detection**:
```bash
hv monitoring-config
```
- [ ] Detects VM count
- [ ] Detects running services
- [ ] Detects system resources
- [ ] Recommends monitoring level
- [ ] Sets appropriate scrape interval
- [ ] Sets appropriate retention
- [ ] Explains reasoning

**Level validation**:
- [ ] No VMs → Basic
- [ ] Few VMs → Standard
- [ ] Many VMs → Enhanced
- [ ] Very many VMs → Comprehensive

---

## 🔧 **Unified CLI Testing**

### Command Routing
```bash
hv help
hv version
hv vm list
hv status
hv health
```
- [ ] Help shows all commands
- [ ] Version displays correctly
- [ ] VM commands work
- [ ] System commands work
- [ ] All routes to correct scripts

### Error Handling
```bash
hv invalid-command
hv vm
hv vm start
```
- [ ] Unknown command shows error
- [ ] Missing arguments show usage
- [ ] Helpful error messages

---

## 🎯 **Integration Testing**

### Complete Setup Flow
```bash
# 1. Validate requirements
./scripts/validate-system-requirements.sh

# 2. Install CLI
sudo ./scripts/install-hv-cli.sh

# 3. Discover system
hv discover

# 4. Run first-boot
hv first-boot

# 5. Create VM
hv vm-create

# 6. Configure security
hv security-config

# 7. Configure network
hv network-config

# 8. Configure backup
hv backup-config

# 9. Configure monitoring
hv monitoring-config
```
- [ ] All steps complete without errors
- [ ] Configurations are consistent
- [ ] Files created in correct locations
- [ ] No permission errors
- [ ] Recommendations make sense together

### Configuration File Validation
```bash
# Check generated configs
ls -la /etc/hypervisor/
cat /etc/hypervisor/security-config.json
cat /etc/hypervisor/network-config.json
cat /etc/hypervisor/backup-config.json
cat /etc/hypervisor/monitoring-config.json
```
- [ ] All config files created
- [ ] JSON is valid
- [ ] Timestamps present
- [ ] Detection metadata included

---

## 📊 **User Experience Testing**

### Beginner User Flow
**Scenario**: New user, no experience
```bash
hv defaults-demo    # Learn how it works
hv vm-create        # Accept all defaults
```
- [ ] Demo is educational
- [ ] Wizards explain clearly
- [ ] Defaults work without changes
- [ ] User feels confident

### Advanced User Flow
**Scenario**: Expert wanting control
```bash
hv discover         # Review detection
hv vm-create        # Override defaults
```
- [ ] Can see all detection
- [ ] Can override everything
- [ ] Understands implications
- [ ] Gets desired configuration

### Time Measurement
- [ ] VM creation: < 5 minutes total
- [ ] Security config: < 5 minutes
- [ ] Complete setup: < 25 minutes

---

## 🐛 **Error Scenarios**

### Missing Dependencies
```bash
# Temporarily rename a required command
sudo mv /usr/bin/jq /usr/bin/jq.bak
hv vm-create
sudo mv /usr/bin/jq.bak /usr/bin/jq
```
- [ ] Clear error message
- [ ] Suggests how to fix
- [ ] Doesn't crash

### Low Resources
Test on system with:
- [ ] 2GB RAM → Warns about limitations
- [ ] 1 CPU core → Provides minimum recommendations
- [ ] < 20GB free space → Warns about disk space

### Permission Issues
```bash
# Run without sudo when needed
hv first-boot  # (requires root)
```
- [ ] Clear permission error
- [ ] Suggests using sudo
- [ ] No cryptic messages

### Network Issues
```bash
# Test with no network connectivity
hv network-config
```
- [ ] Handles no interfaces gracefully
- [ ] Doesn't crash
- [ ] Provides fallback

---

## 📝 **Documentation Verification**

### README
- [ ] Installation instructions work
- [ ] Links are correct
- [ ] Examples are accurate
- [ ] Quick start is clear

### WIZARD_GUIDE.md
- [ ] All wizards documented
- [ ] Examples match actual output
- [ ] Troubleshooting helps
- [ ] Clear and comprehensive

### Man Pages / Help
```bash
hv help
hv help vm
hv vm-create --help
```
- [ ] Help is comprehensive
- [ ] Examples work
- [ ] Clear usage information

---

## ✅ **Acceptance Criteria**

Before marking as production-ready:

### Functional
- [ ] All wizards run without errors
- [ ] Detection is accurate (±10%)
- [ ] Recommendations follow best practices
- [ ] Configurations are valid
- [ ] No security compromises

### User Experience
- [ ] 90%+ users can accept defaults
- [ ] Explanations are clear
- [ ] Errors are helpful
- [ ] Time savings achieved

### Quality
- [ ] No crashes or hangs
- [ ] Clean error handling
- [ ] Proper logging
- [ ] Documentation accurate

### Performance
- [ ] Detection < 5 seconds
- [ ] Wizards responsive
- [ ] No long waits without feedback

---

## 🚨 **Known Issues to Watch For**

1. **Virtualization Detection**
   - Some CPUs report virtualization differently
   - Check both /proc/cpuinfo and kvm module

2. **Storage Type Detection**
   - USB drives may report as SSD
   - Network mounts need special handling

3. **Memory Calculations**
   - Available vs Total can vary
   - Buffer/cache affects "available"

4. **Dialog Tool**
   - Whiptail vs dialog differences
   - Fallback to plain prompts if neither present

5. **Permissions**
   - Some operations require root
   - Clear sudo prompts needed

---

## 📋 **Testing Sign-Off**

### Test Environment
- [ ] Tested on NixOS
- [ ] Tested on other Linux (if applicable)
- [ ] Multiple hardware configurations
- [ ] Virtual and physical machines

### Testers
- [ ] Developer testing complete
- [ ] User acceptance testing
- [ ] Edge case testing
- [ ] Performance testing

### Results
- [ ] All critical tests pass
- [ ] Known issues documented
- [ ] Workarounds provided
- [ ] Ready for production

---

**Testing completed by**: ________________  
**Date**: ________________  
**Production approval**: ________________  

---

*Part of Hyper-NixOS v2.0+ Testing*  
*Intelligent Defaults Implementation*
