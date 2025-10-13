# AI Assistant Context for Hyper-NixOS

## Project Overview

Hyper-NixOS is a comprehensive, security-focused virtualization platform built on NixOS. It provides enterprise-grade features while maintaining simplicity for home labs and development environments.

### Version: 1.0.0
### Status: Production Ready
### Release Date: January 1, 2025

## Core Architecture

### Module System
The project uses NixOS modules organized into categories:
- **Core**: Base system, directories, optimization
- **Features**: Modular feature management with risk assessment
- **Security**: Privilege separation, threat detection, response
- **Virtualization**: libvirt, QEMU integration
- **Networking**: Bridges, NAT, isolation
- **Services**: SSH, monitoring, APIs

### Key Design Principles
1. **Security First**: Every feature evaluated for security impact
2. **Modular Design**: Features can be enabled/disabled independently
3. **Privilege Separation**: VM operations don't require sudo
4. **User Adaptability**: Documentation and UI adapt to user level
5. **Risk Awareness**: Clear security implications for all features

## Major Components

### 1. Privilege Separation Model
- VM operations work without sudo for users in libvirtd group
- System operations require explicit sudo with clear messaging
- Polkit rules for GUI tools
- Group-based access control

### 2. Threat Detection System
- Real-time monitoring with multiple sensors
- Machine learning anomaly detection
- Behavioral analysis for zero-day threats
- Automated response playbooks
- Threat intelligence integration
- Comprehensive reporting

### 3. Feature Management
- Risk-based feature categorization (minimal → critical)
- Dependency resolution
- Compatibility checking
- Security impact assessment
- Interactive setup wizard

### 4. User Experience
- Adaptive documentation (beginner/intermediate/expert)
- Interactive tutorials with progress tracking
- Console-based menu system
- Context-aware help
- Multiple output formats

## Technical Stack

### Core Technologies
- **Base OS**: NixOS 24.05+
- **Virtualization**: QEMU/KVM with libvirt
- **Languages**: Nix, Bash, Python 3
- **Monitoring**: Prometheus, Grafana
- **Security**: Suricata, YARA, custom ML models
- **Networking**: Open vSwitch capable

### Optimized Components
- **Performance**: Rust for critical paths
- **Web UI**: Go backend + Vue.js frontend
- **Configuration**: TOML with schema validation
- **Database**: SQLite for embedded data
- **Message Queue**: NATS for events
- **API**: gRPC + REST gateway

## Configuration Structure

### Main Configuration File
`/etc/nixos/configuration.nix` imports all modules and defines:
- System identification
- Boot parameters
- Hypervisor settings
- User definitions
- Service configurations

### Feature Selection
Users run `hv setup` wizard to:
1. Select experience level
2. Choose risk tolerance
3. Enable/disable features
4. Generate custom configuration

### Module Pattern
```nix
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.hypervisor.module.name;
in {
  options.hypervisor.module.name = {
    enable = mkEnableOption "description";
  };
  config = mkIf cfg.enable {
    # Implementation
  };
}
```

## Security Model

### Two-Phase Approach
1. **Setup Phase**: Permissive for initial configuration
2. **Hardened Phase**: Restrictive for production

### Threat Response Levels
- **Monitor**: Log only
- **Interactive**: Prompt before action
- **Automatic**: Immediate response

### Detection Capabilities
- Known threats via signatures
- Unknown threats via behavior
- Zero-day via ML anomaly detection
- APT via pattern correlation

## Command Structure

### Main CLI: `hv`
All operations go through the unified `hv` command:
- `hv setup` - Initial configuration
- `hv vm` - VM management
- `hv security` - Security operations
- `hv monitor` - Real-time monitoring
- `hv help` - Context-aware help

### VM Operations (No Sudo)
- `vm-start <name>`
- `vm-stop <name>`
- `virsh list --all`
- `virsh console <name>`

### System Operations (Sudo Required)
- `sudo hv system config`
- `sudo hv security setup`
- `sudo nixos-rebuild switch`

## Development Guidelines

### Adding New Features
1. Create module in appropriate category
2. Define risk level and security impacts
3. Update feature-categories.nix
4. Add to documentation
5. Create tests

### Script Standards
- Include standard header with copyright
- Declare sudo requirements
- Source common libraries
- Use standardized exit codes
- Provide help function

### Testing Requirements
- Unit tests for functions
- Integration tests for features
- CI/CD compatibility testing
- Security impact assessment
- Performance benchmarking
- Documentation review

### CI/CD Testing Considerations
1. **Environment Detection**: Always check `CI` environment variable
2. **Path Management**: Use configurable paths, not hardcoded
3. **Dependency Handling**: Mock or install missing tools
4. **Test Structure**: Setup environment BEFORE sourcing libraries
5. **Graceful Degradation**: Skip system-dependent tests in CI

Example CI-friendly test:
```bash
# Setup test environment first
export HYPERVISOR_LOGS="$TEST_DIR/logs"
mkdir -p "$HYPERVISOR_LOGS"

# Then source libraries
source common.sh

# Handle CI limitations
if [[ "${CI:-false}" == "true" ]]; then
    # Mock system commands or skip tests
fi
```

## Known Patterns & Solutions

### Infinite Recursion Prevention
Never access `config` in top-level `let` bindings:
```nix
# ❌ Wrong
let
  value = config.some.option;
in { ... }

# ✅ Correct
config = mkIf condition {
  # Access config here
};
```

### Permission Handling
Always check group membership for VM operations:
```bash
check_vm_group_membership || exit $EXIT_PERMISSION_DENIED
```

### Feature Dependencies
Use the feature manager for dependency resolution:
```nix
featureDependencies = {
  webDashboard = [ "monitoring" ];
  remoteBackup = [ "localBackup" ];
};
```

## Project Structure

```
hyper-nixos/
├── configuration.nix          # Main configuration
├── modules/                   # NixOS modules
│   ├── core/                 # Core system
│   ├── features/             # Feature management
│   ├── security/             # Security components
│   ├── networking/           # Network config
│   └── virtualization/       # VM management
├── scripts/                   # Management scripts
│   ├── lib/                  # Shared libraries
│   └── menu/                 # Menu system
├── packages/                  # Custom packages
├── docs/                     # Documentation
└── tests/                    # Test suites
```

## Integration Points

### External Services
- Prometheus for metrics export
- Slack/email for alerts
- S3/NFS for backups
- LDAP/AD for authentication
- Kubernetes for orchestration

### APIs
- REST API for basic operations
- GraphQL for complex queries
- gRPC for high-performance
- WebSocket for real-time updates

## Performance Considerations

### Resource Usage
- Base system: ~2GB RAM
- Per VM overhead: ~100MB
- Threat detection: ~500MB
- ML models: ~1GB when active

### Optimization Strategies
- Lazy loading of features
- Async processing for monitoring
- Resource pooling for VMs
- Efficient data structures

## Future Roadmap

### Planned Features
- Kubernetes operator
- Cloud provider integration
- Mobile management app
- Cluster management
- Advanced automation

### Enhancement Areas
- GPU virtualization improvements
- Container integration expansion
- Enhanced threat intelligence
- Performance optimizations

## Debugging & Troubleshooting

### Common Issues
1. Permission denied → Check group membership
2. Infinite recursion → Review module patterns
3. Build failures → Check syntax with --show-trace
4. VM won't start → Check logs and resources
5. CI test failures → See CI/CD Testing Considerations above

### Debug Commands
```bash
# NixOS build debug
nixos-rebuild test --show-trace

# Service status
systemctl status hypervisor-*

# Threat detection logs
journalctl -u hypervisor-threat-detector -f

# VM logs
virsh dominfo <vm-name>
```

## Community & Support

### Resources
- Documentation: `/etc/hypervisor/docs/`
- Issue Tracker: GitHub repository
- Community Forum: https://hyper-nixos.org
- Security Contact: security@hyper-nixos.org

### Contributing
- Follow code standards
- Include tests
- Update documentation
- Security review required

---

This context should be used to maintain consistency when assisting with Hyper-NixOS development, troubleshooting, or enhancements.