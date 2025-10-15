# Hyper-NixOS Directory Structure

**Quick Reference**: Understanding the repository organization

---

## 📂 Root Directory

```
/workspace/
├── configuration.nix           # NixOS main config (IMMUTABLE location)
├── hardware-configuration.nix  # Hardware-specific config (auto-generated)
├── flake.nix                   # Nix flake entry point
├── install.sh                  # Universal installer (NixOS + remote)
├── install-legacy.sh           # Legacy installer (preserved)
├── README.md                   # Project overview
├── CREDITS.md                  # Attribution and credits
├── LICENSE                     # Project license
└── DIRECTORY_STRUCTURE.md      # This file
```

**Principle**: Minimal root directory (Design Ethos - Pillar 2)

---

## 🔧 Core System Directories

### `/modules/` - NixOS Modules (1.1MB, 105 files)
Topic-segregated modular configuration

```
modules/
├── core/                # Core system functionality
├── security/            # Security features and hardening
├── monitoring/          # Monitoring and observability
├── automation/          # CI/CD and automation
├── features/            # Feature management
├── virtualization/      # VM and container features
├── clustering/          # Cluster and mesh networking
├── network-settings/    # Network configuration
├── storage-management/  # Storage tiers and management
├── vm-management/       # VM lifecycle management
├── api/                 # GraphQL API
├── gui/                 # GUI components
├── web/                 # Web interfaces
└── enterprise/          # Enterprise features
```

### `/profiles/` - Configuration Profiles
Pre-configured system variants

```
profiles/
├── minimal.nix              # Minimal footprint
├── enhanced.nix             # Balanced features
├── complete.nix             # Full feature set
├── recovery.nix             # Recovery/rescue mode
└── privilege-separation.nix # Security-focused
```

### `/scripts/` - Operational Scripts (2.1MB, 146 files)
Shell scripts for system operations

```
scripts/
├── lib/                 # Shared libraries
│   ├── common.sh        # Common functions
│   ├── ui.sh            # UI components
│   └── system.sh        # System utilities
├── menu/                # Menu system
├── security/            # Security operations
├── monitoring/          # Monitoring setup
├── automation/          # Automation tools
├── audit/               # Audit tools
├── setup/               # Setup wizards
├── examples/            # Example scripts
└── tools/               # Development tools
```

---

## 📚 Documentation Directories

### `/docs/` - User Documentation (1.2MB, 93 files)

```
docs/
├── INSTALLATION_GUIDE.md    # Installation documentation
├── QUICK_START.md           # Quick start guide
├── ADMIN_GUIDE.md           # Administrator guide
├── FEATURES.md              # Complete feature list
├── user-guides/             # User-facing guides
├── guides/                  # How-to guides
├── reference/               # Technical reference
├── deployment/              # Deployment guides
├── archive/                 # Archived/legacy docs
└── dev/                     # Development docs (PROTECTED)
```

### `/docs/dev/` - Development Documentation (PROTECTED)
**⚠️ Internal Use Only** - Proprietary development documentation

Contains:
- Design ethos and principles
- AI assistant context and guidelines
- Development history and learnings
- Architecture documentation
- Reference repository information
- **Agent usage guides** (crash prevention)

**Important for AI Agents**: Read `AGENT_QUICK_REFERENCE.md` first to prevent crashes!

**See**: `/docs/dev/README_PROTECTED.md` for access restrictions

---

## 🛠️ Configuration Directories

### `/config/` - System Configuration Files
Global hypervisor system settings

```
config/
├── hypervisor.toml          # Main system config (TOML)
└── module-config-schema.yaml # Module schema
```

**Purpose**: System-wide configuration  
**See**: `/config/README.md`

### `/configs/` - Service Configurations
Service-specific configuration files

```
configs/
└── docker/                  # Docker/container configs
    ├── daemon.json
    └── security-policy.json
```

**Purpose**: Per-service settings  
**See**: `/configs/README.md`

---

## 🖥️ Infrastructure Directories

### `/vm_profiles/` - VM Templates
JSON-based VM profile templates

```
vm_profiles/
├── debian-desktop.json
├── ubuntu-server.json
├── windows-10.json
├── minimal-linux.json
└── development.json
```

### `/monitoring/` - Monitoring Configurations
Prometheus, Grafana, and alerting configs

```
monitoring/
├── prometheus.yml
├── alert-rules.yml
├── dashboards/
└── rules/
```

### `/isos/` - ISO Storage
Operating system ISOs for VM installation

**Note**: Empty in repository, populated by users  
**See**: `/isos/README.md`

---

## 🔨 Development Directories

### `/tools/` - Development Tools
Rust-based tooling

```
tools/
├── Cargo.toml
├── src/
└── target/              # Build artifacts (gitignored)
```

### `/tests/` - Test Suite
Integration and unit tests

```
tests/
├── *.bats               # Bash automated tests
├── *.sh                 # Shell test scripts
└── integration-*.sh     # Integration tests
```

### `/examples/` - Example Configurations
Sample configurations and use cases

---

## 🌐 Interface Directories

### `/api/` - GraphQL API Server
Go-based event-driven API

```
api/
├── main.go
├── go.mod
└── graphql/
```

### `/web/` - Web Interfaces
HTML/JS web components

### `/hypervisor_manager/` - Legacy Python Manager
**Status**: Deprecated (preserved for reference)

**See**: `/hypervisor_manager/README.md`

---

## 📦 Build & Package Directories

### `/build/` - Build Scripts
Portable build tooling

### `/packages/` - Nix Packages
Custom NixOS package definitions

```
packages/
└── hypervisor-cli.nix
```

### `/install/` - Installation Tools
Cross-platform installation support

**See**: `/install/README.md` for portable installer

---

## 🔗 External Resources

### `/external-repos/` - Reference Repositories
**Size**: 1.8GB (gitignored)  
**Purpose**: Reference code for learning patterns

Contains cloned repositories:
- NixOS official (nixpkgs)
- Virtualization (Harvester, Proxmox)
- Networking (Cilium, OVS)
- Security (Vault, MaxOS)
- Storage (ZFS, Restic)
- Monitoring (Grafana)

**See**: `/external-repos/README.md` and `/docs/dev/REFERENCE_REPOSITORIES.md`

---

## 📋 Organization Principles

Following **Design Ethos - Pillar 2: Security & Organization**

### ✅ Best Practices Applied

1. **Minimal Root Directory**
   - Only essential files in root
   - Everything else organized in subdirectories

2. **Topic Segregation**
   - Modules organized by functionality
   - Clear naming conventions
   - Logical grouping

3. **Documentation Co-location**
   - README.md in directories needing explanation
   - Purpose and usage clearly stated

4. **No Clutter**
   - Build artifacts gitignored
   - No backup files in version control
   - No ad-hoc generated files

5. **Strict Enforcement**
   - Well-labeled subdirectories
   - Clear separation of concerns
   - Consistent structure

---

## 🔍 Quick Find

**Looking for...**
- **Installation?** → `/install.sh`, `/docs/INSTALLATION_GUIDE.md`
- **Configuration?** → `/configuration.nix`, `/config/hypervisor.toml`
- **Scripts?** → `/scripts/` (check `/scripts/menu.sh` for main menu)
- **Documentation?** → `/docs/` (start with `/docs/README-DOCS.md`)
- **Modules?** → `/modules/` (see `/modules/default.nix`)
- **VM Templates?** → `/vm_profiles/`
- **Tests?** → `/tests/`
- **Development?** → `/docs/dev/` (protected)

---

*Last Updated: 2025-10-15*  
*Hyper-NixOS v2.0+*
