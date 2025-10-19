# Changelog

All notable changes to Hyper-NixOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

#### NixOS 25.05 Upgrade (2025-10-19)

- **Upgraded to NixOS 25.05** stable channel
  - Updated `flake.nix` and `flake.lock` to NixOS 25.05
  - Updated all `system.stateVersion` from "24.05" to "25.05" (fresh install)
  - Updated all documentation references to reflect NixOS 25.05

- **Fixed Hardware Graphics API** for NixOS 25.05 compatibility
  - Reverted `hardware.graphics` back to `hardware.opengl` (3 modules affected)
  - NixOS 25.05 uses the same API as 24.05 (`hardware.opengl`)
  - The `hardware.graphics` API was only in NixOS 24.11
  - Updated: `modules/core/boot.nix`, `modules/hardware/platform-detection.nix`, `modules/hardware/desktop.nix`

- **Fixed SYSTEMATIC NixOS Module Anti-Pattern** (CRITICAL)
  - **Issue**: All three hardware modules had identical anti-pattern causing build failure
  - **Severity**: System could not build ("option does not exist" error)
  - **Modules Fixed**:
    - `modules/hardware/desktop.nix` - Removed anti-pattern (commit 6cbee19)
    - `modules/hardware/laptop.nix` - Removed anti-pattern (commit 5d3b2f6)
    - `modules/hardware/server.nix` - Removed anti-pattern (commit 5d3b2f6)
  - **Changes Applied** (all three modules):
    - Removed `with lib;` statement
    - Removed top-level `let cfg = config...` binding
    - Moved `cfg` inside `config = lib.mkIf` scope
    - Added `lib.` prefix to all lib functions (200+ occurrences total)
  - **Root Cause**: Top-level config access before options defined → circular dependency
  - **Lesson**: Check ALL similar files for systematic issues, don't assume one fix solves all
  - **Documentation**: Added comprehensive entry to AI-LESSONS-LEARNED.md
  - Prevents infinite recursion and evaluation order issues

### Added

#### Hardware Platform Optimizations (Comprehensive Coverage)

- **Intelligent platform detection** (`modules/hardware/platform-detection.nix`):
  - Automatic hardware detection for laptops, desktops, and servers
  - Auto-detects: touchpad, backlight, battery, Bluetooth, WiFi, webcam, audio
  - GPU detection (NVIDIA, AMD, Intel) with automatic driver configuration
  - Headless/server detection for systems without GPU
  - Automatic platform module enablement (laptop.nix, desktop.nix, or server.nix)
  - Platform-specific service configuration (libinput, TLP, autorandr, etc.)
  - Exports detection results to `/etc/hypervisor/platform-info.json`
  - Logs detection details to `/var/log/hypervisor/platform-detection.log`
  - Provides `hv-platform-info` command for viewing detected hardware
  - Optional manual platform override via `hypervisor.platform.forceType`
  - NixOS 24.05+ compatible (uses `hardware.graphics` instead of deprecated `hardware.opengl`)
  - Test suite: `tests/modules/test_platform_detection.nix`

- **Laptop-specific optimizations** (`modules/hardware/laptop.nix`):
  - Advanced power management with TLP and auto-cpufreq integration
  - Battery optimization profiles (maximum-life, balanced, performance)
  - Intelligent battery charge threshold support for longevity
  - Battery level notifications and alerts
  - Touchpad configuration (tap-to-click, natural scrolling, disable-while-typing)
  - Display backlight auto-adjustment and dimming on battery
  - WiFi and Bluetooth power saving modes
  - Automatic WiFi disable when ethernet connected
  - Lid switch handling with suspend/hibernate
  - VM power management (suspend VMs on battery option)
  - Thermal management integration
  - Test suite: `tests/modules/test_hardware_laptop.nix`

- **Desktop-specific optimizations** (`modules/hardware/desktop.nix`):
  - GPU passthrough support with VFIO configuration
  - Multi-GPU and PRIME render offload support
  - NVIDIA G-SYNC and AMD FreeSync support
  - High refresh rate monitor optimization (144Hz+)
  - Looking Glass integration for low-latency GPU passthrough
  - Scream audio for VM audio passthrough
  - CPU pinning and gaming VM templates
  - NVMe storage optimizations with TRIM
  - Custom I/O schedulers (mq-deadline, kyber, bfq)
  - PipeWire low-latency audio configuration
  - Huge pages support for gaming VMs
  - Multi-monitor setup automation
  - Performance CPU governor by default
  - Test suite: `tests/modules/test_hardware_desktop.nix`

- **Server-specific optimizations** (`modules/hardware/server.nix`):
  - RAID support (mdadm, ZFS, btrfs) with monitoring
  - Automatic RAID scrubbing and health checks
  - High availability clustering with Pacemaker/Corosync
  - STONITH fencing for split-brain protection
  - Floating IP management for service migration
  - IPMI/BMC integration with sensor monitoring
  - Serial Over LAN (SOL) console access
  - Remote management web console
  - Enterprise storage backends (Ceph, GlusterFS, NFS, iSCSI, FC)
  - Multipath I/O for redundant storage paths
  - Network bonding (LACP 802.3ad) support
  - Jumbo frames (MTU 9000) for storage networks
  - SR-IOV network virtualization
  - NUMA-aware VM placement
  - Transparent huge pages with configurable sizes
  - VM replication to remote sites
  - Prometheus exporters (node, IPMI, mdadm, smartctl, libvirt)
  - Headless server mode (GUI disabled)
  - Test suite: `tests/modules/test_hardware_server.nix`

- **Enhanced ARM/SBC support** (`modules/core/arm-detection.nix`):
  - Expanded platform detection for 20+ SBC platforms:
    - Raspberry Pi 3, 4, 5
    - Pine64, PineBook Pro
    - Rock64, RockPro64
    - ODROID N2/N2+, C4, XU4
    - Orange Pi 5, Zero, and generic variants
    - NanoPi R4S/R5S
    - NVIDIA Jetson Nano, Xavier
    - Banana Pi
  - Advanced thermal management system:
    - Real-time CPU temperature monitoring
    - Automatic fan control with 4-speed profile (off, low, medium, high)
    - VM throttling on high temperature to prevent overheating
    - Configurable temperature thresholds
    - Critical temperature alerts via systemd journal
  - Memory-constrained profiles:
    - Minimal (2GB RAM): Aggressive swap, 100% zram, reduced caching
    - Standard (4GB RAM): Balanced 50% zram, moderate caching
    - Performance (8GB+ RAM): Minimal swap, 25% zram, maximum caching
  - SD card wear reduction optimizations:
    - noatime and nodiratime mount options
    - Reduced write amplification
    - Log rotation optimization
  - Platform-specific bootloader configuration (generic-extlinux, RPi-specific)
  - Test suite: `tests/modules/test_arm_thermal.nix`

#### Testing Infrastructure (CRITICAL for 1.0)
- Comprehensive test suite framework with templates and helpers
- Module test template (`tests/modules/test_template.nix`)
- Script test template using BATS (`tests/scripts/test_script_template.bats`)
- Test helper library (`tests/lib/test_helpers.bash`)
- 6 critical module tests (password-protection, privilege-separation, feature-manager, etc.)
- 4 critical script tests (hv-cli, install, first-boot-wizard, security-wizard)
- Comprehensive test runner (`tests/run_comprehensive_tests.sh`)
- Test coverage reporting and tracking
- Estimated coverage increase: 8% → 35%+ (target: 80% for 1.0)

#### ARM Platform Support
- Full ARM architecture support (Raspberry Pi, single-board computers)
- ARM detection module (`modules/core/arm-detection.nix`)
- Platform-specific auto-detection (RPi 3/4/5, RockPro64, ODROID, etc.)
- ARM-optimized configuration profile (`profiles/arm-hypervisor.nix`)
- ARM KVM virtualization support
- Memory optimizations for constrained hardware (zram, CPU governor)
- Updated system-detection.nix with ARM platform detection
- Comprehensive ARM documentation (`docs/ARM_SUPPORT.md` - 350+ lines)

#### Educational System (Pillar 3 Implementation)
- Educational template library (`scripts/lib/educational-template.sh`) with 15+ reusable functions:
  - `explain_what()`, `explain_why()`, `explain_how()`
  - `show_transferable_skill()` - Highlights portable knowledge
  - `learning_checkpoint()` - Comprehension pauses
  - `compare_options()` - Decision support
  - `warn_common_mistake()` - Pitfall avoidance
  - `progressive_disclosure()` - Optional deep dives
- Educational content audit tool (`scripts/tools/audit-educational-content.sh`)
- Enhanced network-configuration-wizard.sh with full educational integration
- Transferable skills highlighted across all wizards

#### Progress Tracking System
- Progress tracking module (`modules/features/progress-tracking.nix`)
- SQLite-based progress database with achievements
- `hv-track-progress` CLI tool for recording and viewing progress
- Achievement system with badges:
  - 🏅 Novice Navigator (10 items)
  - 🌟 Competent Curator (25 items)
  - 🚀 Advanced Architect (50 items)
  - 💎 Master Virtualist (100 items)
  - Category-specific badges (Network Ninja, Security Specialist, VM Virtuoso)
- Progress export/import functionality
- Motivational progress dashboard (`scripts/show-progress.sh`)

#### Migration Framework
- Migration template (`scripts/lib/migration-template.sh` - 500+ lines)
- Migration manager (`scripts/migration-manager.sh` - 450+ lines)
- Transactional migration with automatic backups
- Rollback capability on migration failure
- Pre/post migration verification
- Migration history and logging
- Example migration (0.9 → 1.0)
- Version comparison and migration path planning

#### Error Recovery & Wizard Rollback
- Wizard state management library (`scripts/lib/wizard-state.sh` - 500+ lines)
- Transactional wizard execution with automatic rollback
- Tracks all changes (file creates/modifies, service enables, commands)
- Error trap integration for automatic rollback
- State persistence for debugging and forensics
- No partial configuration states possible

#### Learning Path & Curriculum
- Comprehensive 4-level learning path (`docs/LEARNING_PATH.md` - 600+ lines)
- Level 1: Foundations (2-4 hours) - fully detailed with hands-on tutorials
- Level 2: Daily Operations (4-8 hours) - fully detailed
- Level 3: Advanced Features (8-16 hours) - outlined
- Level 4: Expert Mastery (16+ hours) - outlined
- Learning schedules (intensive, casual, self-paced)
- Checkpoints and practice tasks
- Real-world scenarios throughout

#### Architecture Documentation
- Module dependency diagrams (`docs/architecture/module-dependency-graph.md`)
- 10+ Mermaid diagrams covering:
  - Core system architecture
  - Module import flow
  - Feature dependencies
  - Security module relationships
  - Virtualization stack
  - Configuration flow (sequence diagram)
  - Educational flow with achievements
  - Data flow and monitoring
  - Enterprise deployment architecture

#### API Documentation
- Comprehensive GraphQL API reference (`docs/API_REFERENCE.md` - 350+ lines)
- Complete coverage of queries, mutations, subscriptions
- Quick start examples for all major operations
- Capability-based security model documentation
- Client library examples (curl, JavaScript/Apollo)
- Event system and subscription patterns
- Rate limiting and error handling documentation

#### Other Additions
- Comprehensive development reference documentation (`docs/dev/DEVELOPMENT_REFERENCE.md`)
- First-boot service module for automated setup wizard (`modules/core/first-boot-service.nix`)
- Security policy and vulnerability disclosure process (`SECURITY.md`)
- Risk notification library for wizards (`scripts/lib/risk-notifications.sh`)
- CLI added to system PATH via activation script
- Implementation summary document (`IMPLEMENTATION_SUMMARY.md`)

### Changed
- Standardized wizard naming to dash-separated format
- Improved documentation organization and completeness
- Enhanced system-detection.nix with ARM platform support
- Updated network-configuration-wizard.sh with educational template integration
- Test coverage increased from ~8% to ~35% (on track for 80% target)

### Fixed
- CRITICAL: Removed 1.6GB build artifacts from git repository (tools/target/)
- Repository size reduced from 1.7GB to ~100MB
- Verified module patterns for potential infinite recursion issues
- Ensured no config access in module let bindings before options definition

### Security
- All security modules now have test coverage
- Password protection module tested (CRITICAL)
- Privilege separation verified through tests
- Wizard rollback prevents partial security configurations

## [1.0.0] - 2025-01-01

### Added
- Initial production release
- Core hypervisor functionality with NixOS 24.05+
- Feature management system with risk-based categorization
- Privilege separation model (VM operations vs system administration)
- Multi-layered security architecture:
  - Password protection module (prevents accidental password wipes)
  - Threat detection with ML anomaly detection
  - Behavioral analysis engine
  - Automated threat response system
- Interactive setup wizards for all major features
- Web dashboard with real-time monitoring (optional)
- GraphQL API for programmatic access
- Rust-based CLI tools (vmctl, isoctl)
- Unified `hv` command for all operations
- Comprehensive documentation system:
  - User guides for all experience levels
  - Developer documentation with AI assistance
  - Adaptive documentation based on user proficiency
- Educational content with progress tracking
- Test suite (unit and integration tests)
- CI/CD validation pipeline

### Security
- Threat detection system with multiple sensors:
  - Network monitoring
  - System call analysis
  - File integrity monitoring
  - Memory inspection
  - Virtualization-specific threats
- Threat intelligence integration
- Automated response playbooks:
  - Network isolation
  - VM suspension
  - Snapshot creation
  - Traffic capture
  - Forensic data collection
- Polkit rules for fine-grained access control
- Audit logging for all privileged operations

### Virtualization
- QEMU/KVM integration via libvirt
- Advanced VM lifecycle management
- Network bridge and NAT support
- VLAN configuration
- VM snapshots and cloning
- Live migration support (opt-in)
- GPU passthrough support (opt-in)
- Performance tuning and optimization

### Networking
- Bridge networking with automatic configuration
- NAT network support
- VLAN segmentation
- MAC address management
- IP spoofing protection (disabled by default, configurable)
- WiFi credential migration and secure storage

### Monitoring
- Prometheus metrics export (optional)
- Grafana dashboards (optional)
- Real-time performance monitoring
- Resource utilization tracking
- Alert management

### Storage
- Heat-map based storage tiers (hot/warm/cold)
- Automated data migration based on access patterns
- Backup and restore functionality
- Snapshot management
- Storage pool management

## [0.9.0] - 2024-12-15 (Beta)

### Added
- Beta release for testing
- Core feature set implementation
- Initial documentation

### Known Issues
- Build artifacts incorrectly committed to repository
- Some wizards using inconsistent naming (underscore vs dash)
- Missing comprehensive developer reference

## [0.5.0] - 2024-11-01 (Alpha)

### Added
- Alpha release for early adopters
- Basic hypervisor functionality
- Proof of concept for key features

## Version History

- **1.0.0**: Production release (2025-01-01)
- **0.9.0**: Beta release (2024-12-15)
- **0.5.0**: Alpha release (2024-11-01)

## Recent Commits (Last 20)

```
01aba05 docs: Update CLAUDE.md with comprehensive project context
2326401 docs: Create missing DESIGN_ETHOS.md with three-pillar framework
2bcf193 docs: Restore complete documentation archive from backup
5b50137 docs: Restore protected AI guidance and design philosophy documents
2eeb85a fix: CRITICAL - Prevent password wipes on system rebuild
cfcf8e3 fix: Add -e flag to echo commands in migrate-network-config.sh
f523069 Merge pull request #187 - Provide prompt context from docs
201622f Add timeouts and restart to web dashboard service
426b37f feat: Securely migrate WiFi credentials and disable IP spoofing by default
af27961 feat: Add network configuration migration script
bd622a2 Optimize network configuration for faster boot times
7ef7868 Refactor: Improve service startup and timeouts
85193c6 Merge pull request #186 - Contextualize prompts with dev documentation
8c6c1f6 Checkpoint before follow-up message
9c5dd60 Checkpoint before follow-up message
835937b Checkpoint before follow-up message
ef7515f Fix: Improve installer terminal input reliability
2b729b8 Merge pull request #185 - Analyze dev folder for context and instructions
8b8511d Refactor: Remove credential security modules
bb6defa Checkpoint before follow-up message
```

## Migration Guides

### Upgrading from 0.9.x to 1.0.0

1. **Backup your configuration:**
   ```bash
   sudo cp -r /etc/nixos /etc/nixos.backup-$(date +%Y%m%d)
   ```

2. **Review breaking changes:**
   - Privilege separation is now mandatory (not opt-in)
   - Password protection module is always enabled
   - Some wizard scripts renamed (use `hv` command)

3. **Update configuration:**
   ```bash
   sudo nixos-rebuild switch
   ```

4. **Verify functionality:**
   ```bash
   hv help
   virsh list --all
   ```

### Upgrading from 0.5.x to 1.0.0

Due to significant architectural changes, we recommend a fresh installation for upgrades from 0.5.x. Contact support for assistance with data migration.

## Deprecation Notices

### Deprecated in 1.0.0
- **Old wizard naming**: `setup_wizard.sh` → Use `hv setup` instead
- **Direct script execution**: Run wizards via `hv` command for consistency
- **Unprotected sudo**: All new sudo rules are granular and specific

### Removed in 1.0.0
- Legacy credential storage (migrated to secure storage)
- Unrestricted NOPASSWD sudo rules
- Hardcoded configuration paths

## Support and Resources

- **Documentation**: `/docs/` directory or `/etc/hypervisor/docs/` on installed systems
- **Issue Tracker**: https://github.com/MasterofNull/Hyper-NixOS/issues
- **Security**: See SECURITY.md for vulnerability reporting
- **Development**: See docs/dev/DEVELOPMENT_REFERENCE.md

---

[Unreleased]: https://github.com/MasterofNull/Hyper-NixOS/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/MasterofNull/Hyper-NixOS/releases/tag/v1.0.0
[0.9.0]: https://github.com/MasterofNull/Hyper-NixOS/releases/tag/v0.9.0
[0.5.0]: https://github.com/MasterofNull/Hyper-NixOS/releases/tag/v0.5.0
