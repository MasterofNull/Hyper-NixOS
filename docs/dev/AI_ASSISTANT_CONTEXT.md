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
- **Base OS**: NixOS 25.05 (latest stable)
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

## Recent Fixes & Patterns (Updated 2025-10-13)

### CI Test Environment Issues
When tests fail in CI but work locally, check for:

1. **Readonly Variables in Libraries**
```bash
# Problem: Libraries declare readonly variables
readonly HYPERVISOR_ROOT="/etc/hypervisor"

# Solution in tests: Remove readonly before sourcing
sed -i 's/^readonly HYPERVISOR_/HYPERVISOR_/g' "$TEMP/lib.sh"
```

2. **Exit Calls in Utility Functions**
```bash
# Problem: Function calls exit directly
require() {
    # ...
    exit 1  # This terminates the test script!
}

# Solution: Use subshell in tests
(require nonexistent_command) || echo "Failed as expected"
```

3. **Strict Error Handling Inheritance**
```bash
# Problem: Library sets strict mode
set -Eeuo pipefail  # This affects test execution

# Solution: Disable after sourcing
source common.sh
set +e  # Allow test failures
```

### Nix Configuration Patterns
Always use proper scoping for library functions:

```nix
# ❌ Wrong
mkIf (elem "feature" list)

# ✅ Correct  
mkIf (lib.elem "feature" list)

# ✅ Also correct (with proper import)
with lib;
mkIf (elem "feature" list)
```

**Recent Fix (2025-10-13)**: Fixed undefined variable 'elem' errors in configuration.nix lines 323 and 345 by adding `lib.` prefix.

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

### Python/Script Code in Nix Multiline Strings
When embedding Python, Bash, or other scripts in Nix multiline strings (`''`), single quotes must be escaped:

```nix
# ❌ Wrong - Causes syntax errors
pkgs.writeText "script.py" ''
  data = threat.get('target', '')
  if 'key' in dict:
      print('hello')
''

# ✅ Correct - Single quotes escaped as ''
pkgs.writeText "script.py" ''
  data = threat.get(''target'', '''')
  if ''key'' in dict:
      print(''hello'')
''

# ✅ Alternative - Use double quotes in Python
pkgs.writeText "script.py" ''
  data = threat.get("target", "")
  if "key" in dict:
      print("hello")
''
```

**Recent Fix (2025-10-14)**: Fixed Python single quote escaping in `modules/security/threat-response.nix` and `modules/security/behavioral-analysis.nix`.

### NixOS Version Compatibility
Always check `flake.nix` for target NixOS version before using API options:

```nix
# Check flake.nix first:
# inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

# ❌ Wrong for NixOS 24.05 (these are 24.11 APIs)
hardware.graphics = {
  enable = true;
  enable32Bit = true;
};

# ✅ Correct for NixOS 24.05
hardware.opengl = {
  enable = true;
  driSupport = true;
  driSupport32Bit = true;
};
```

**Key API Changes Between NixOS 24.05 and 24.11**:
- `hardware.opengl` (24.05) → `hardware.graphics` (24.11)
- `hardware.opengl.enable32Bit` (24.05) → `hardware.graphics.enable32Bit` (24.11)
- `hardware.opengl.driSupport` (24.05) → `hardware.graphics.driSupport` (24.11)

**Important**: When fixing version compatibility issues:
1. Check `flake.nix` for NixOS version
2. Scan entire codebase systematically (use `grep -r "hardware\.graphics" modules/`)
3. Fix all instances comprehensively, not one-by-one
4. Verify with `nix-instantiate --parse <file>` after changes

**Recent Fix (2025-10-19)**: Fixed multiple NixOS 24.11 API usage in codebase designed for 24.05. Changed `hardware.graphics` → `hardware.opengl` in platform-detection.nix, desktop.nix, and boot.nix.

### Module Import Requirements
All modules that define options MUST be imported in configuration.nix for those options to exist:

```nix
# ❌ Wrong - module defines options but isn't imported
# File: modules/hardware/platform-detection.nix defines hypervisor.hardware.laptop
# But configuration.nix doesn't import it
# Result: Error "option does not exist"

# ✅ Correct - import ALL modules that define options
imports = [
  ./modules/hardware/platform-detection.nix  # Defines hypervisor.hardware.*
  ./modules/hardware/laptop.nix              # Uses hypervisor.hardware.laptop
  ./modules/hardware/desktop.nix             # Uses hypervisor.hardware.desktop
];
```

**Recent Fix (2025-10-19)**: Added missing `platform-detection.nix` import to configuration.nix.

### Avoiding Duplicate Attribute Definitions
NixOS doesn't allow duplicate attribute definitions. Merge them using `++` with conditionals:

```nix
# ❌ Wrong - Duplicate definitions cause errors
boot.kernelParams = [ "param1" ];
# ... later in file ...
boot.kernelParams = mkIf condition [ "param2" ];  # ERROR!

# ✅ Correct - Single definition with conditionals
boot.kernelParams = [ "param1" ]
  ++ optionals condition [ "param2" ]
  ++ optionals otherCondition [ "param3" ];

# ✅ Also correct for complex conditionals
systemd.tmpfiles.rules =
  (optionals condition1 [ "rule1" ])
  ++
  (optionals condition2 [ "rule2" ]);
```

**Recent Fix (2025-10-19)**: Merged duplicate `boot.kernelParams` and `systemd.tmpfiles.rules` in desktop.nix.

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

### Feature Management System (2025-10-14)
The enhanced feature management system provides:
- **Centralized System Detection**: `modules/core/system-detection.nix` provides unified hardware capability detection
- **Feature Compatibility Checking**: Features validate against hardware capabilities, dependencies, and conflicts
- **Non-selectable Incompatible Options**: UI shows why features can't be selected (insufficient RAM, missing deps, conflicts)
- **Automatic Testing**: Configuration validated with `nixos-rebuild dry-build` before applying
- **Auto-switch Option**: Can automatically apply tested configurations
- **Configuration Process**:
  1. Detection (hardware/capabilities)
  2. Validation (compatibility/resources)
  3. Backup (timestamped copies)
  4. Generation (Nix files)
  5. Testing (dry-build)
  6. Application (switch/boot/VM)

### System Detection Integration
Use centralized detection instead of duplicating:
```bash
# Get full detection
hv-detect-system json

# Check specific capability
source /etc/hypervisor/detection-integration.sh
check_capability "cpu_virt"  # returns true/false
get_hardware_info "ram_gb"   # returns value
```

### Configuration Modification Safety
- Incompatible features are disabled in UI with explanations
- Automatic dependency resolution adds required features
- Conflict detection prevents invalid combinations
- Resource validation ensures system can handle configuration
- Automatic backups before any changes
- Dry-build testing before applying
- Optional auto-switch after successful test

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
6. Undefined Nix variables → Add `lib.` prefix to standard functions
7. Test scripts exiting early → Use subshells for commands that may exit
8. Python/script syntax errors in Nix → Escape single quotes as `''` in multiline strings

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