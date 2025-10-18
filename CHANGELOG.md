# Changelog

All notable changes to Hyper-NixOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive development reference documentation (`docs/dev/DEVELOPMENT_REFERENCE.md`)
- First-boot service module for automated setup wizard (`modules/core/first-boot-service.nix`)
- Security policy and vulnerability disclosure process (`SECURITY.md`)
- Risk notification library for wizards (`scripts/lib/risk-notifications.sh`)
- CLI added to system PATH via activation script

### Changed
- Standardized wizard naming to dash-separated format
- Improved documentation organization and completeness

### Fixed
- CRITICAL: Removed 1.6GB build artifacts from git repository (tools/target/)
- Repository size reduced from 1.7GB to ~100MB

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
