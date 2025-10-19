# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🚨 CRITICAL - READ BEFORE ANY WORK

**STOP**: Before making ANY changes or decisions, you MUST read these foundational documents in `docs/dev/`:

1. **[DESIGN_ETHOS.md](docs/dev/DESIGN_ETHOS.md)** - The three foundational pillars that guide EVERY decision (IMMUTABLE)
2. **[CRITICAL_REQUIREMENTS.md](docs/dev/CRITICAL_REQUIREMENTS.md)** - Mandatory requirements for all operations
3. **[AI-LESSONS-LEARNED.md](docs/dev/AI-LESSONS-LEARNED.md)** - Avoid repeating past mistakes
4. **[PROJECT_DEVELOPMENT_HISTORY.md](docs/dev/PROJECT_DEVELOPMENT_HISTORY.md)** - Historical context and decisions

**These documents prevent circular fixes, maintain project identity, and guide all development.**

---

## 🎯 The Three-Pillar Design Ethos

**ALL decisions must be evaluated against these three foundational pillars:**

### **Pillar 1: Ease of Use**
- Minimize friction at ALL stages (installation, daily use, updates, hardware compatibility)
- **Standard**: If it creates friction, it MUST be addressed and fixed
- User should NEVER struggle with basic operations

### **Pillar 2: Security AND Directory Structure/Organization** (Equal Priority)
- **Security**: ALL design judged against cyber security best practices
  - Users MUST be notified of risks with mitigation guidance
  - Defense in depth, secure by default
- **Organization**: CLEAN, MINIMAL, ORGANIZED (VERY STRICT enforcement)
  - No messy directories, no clutter
  - Well-labeled sub-directories required
  - File system organization reflects logical architecture

### **Pillar 3: Learning Ethos**
- System is BOTH functional tool AND learning tool
- **Transform users**: New → Familiar → Competent
- All user-facing elements facilitate learning (guides, docs, commands, wizards)
- Guide correct implementation while leaving flexibility for advanced users

**See [docs/dev/DESIGN_ETHOS.md](docs/dev/DESIGN_ETHOS.md) for complete framework.**

---

## 🤖 AI Agent Role and Boundaries

**CRITICAL**: You are NOT the decision-maker on high-level design or architecture.

### Your Responsibilities:
1. **PRESENT**: Suggestions, opportunities, insights, relevant information
2. **ASK**: For user's thoughts and direction on design decisions
3. **EXECUTE**: User-provided directions
4. **NEVER**: Make architectural decisions unilaterally or assume user's intent

**The user is the architect. Always ask for direction on major decisions.**

---

## Overview

Hyper-NixOS is a next-generation virtualization platform built on NixOS 25.05 that embodies the three-pillar design ethos. The project emphasizes intelligent defaults, privilege separation, security-first design, clean organization, and learning-focused user experience.

### Project Identity
- **Vision**: World-class, cutting-edge, fully featured hypervisor for all platforms
- **Dual Purpose**: Functional production tool AND comprehensive learning platform
- **Platforms**: ARM mobile, embedded, SBC, laptops, desktops, servers, cloud
- **Status**: Production ready with complete documentation protection

## Development Commands

### Testing

```bash
# Run all tests (integration + unit)
./tests/run_all_tests.sh

# Run specific test categories
./tests/integration/test_*.sh    # Integration tests
./tests/unit/test_*.sh            # Unit tests

# Run CI validation
./tests/ci_validation.sh

# Security integration tests
./tests/integration-test-security.sh
```

### Building

```bash
# Build NixOS configuration
sudo nixos-rebuild build

# Build with specific flake reference
nix build .#packages.x86_64-linux.iso

# Build for different architectures
nix build .#nixosConfigurations.hypervisor-x86_64
nix build .#nixosConfigurations.hypervisor-aarch64

# Portable build (for non-NixOS systems)
./build/portable-build.sh
```

### Rebuilding System

```bash
# Standard rebuild (test configuration)
sudo nixos-rebuild test

# Apply and make bootable
sudo nixos-rebuild switch

# Use flake-based rebuild
nix run .#rebuild-helper

# Quick rebuild for testing
./scripts/rebuild_helper.sh
```

### Rust Tools

The project includes Rust-based CLI tools in `tools/`:

```bash
cd tools/

# Build all tools
cargo build --release

# Build specific tool
cargo build -p vmctl --release
cargo build -p isoctl --release

# Run tests
cargo test

# Individual tool commands
./target/release/vmctl --help
./target/release/isoctl --help
```

### CLI Development

The unified `hv` command is the main entry point:

```bash
# Install the CLI
sudo ./scripts/install-hv-cli.sh

# Test CLI commands
hv help
hv discover          # System discovery
hv vm-create         # VM creation wizard
hv security-config   # Security configuration
```

## Architecture

### Module System

Hyper-NixOS uses a modular NixOS configuration architecture:

- **Core modules** (`modules/core/`): Base system functionality, options, packages, system detection
- **Security modules** (`modules/security/`): Multi-layered security with profiles, privilege separation, threat detection/response
- **Virtualization modules** (`modules/virtualization/`): Libvirt integration, performance tuning, VM lifecycle
- **Feature modules** (`modules/features/`): Feature management system with intelligent categorization
- **GUI modules** (`modules/gui/`): Optional desktop environment, remote access
- **Enterprise modules** (`modules/enterprise/`): Advanced clustering, storage tiers, AI monitoring

All modules are imported via `configuration.nix`, which is the main entry point.

### Configuration Flow

1. **`flake.nix`**: Defines inputs (nixpkgs), outputs (system configurations, apps, ISO)
2. **`configuration.nix`**: Imports all modules, sets system-wide options
3. **`hardware-configuration.nix`**: Auto-generated hardware-specific settings
4. **Module imports**: Each category (core, security, virtualization, etc.) provides discrete functionality
5. **User customization**: `hypervisor-features.nix` (generated by setup wizard)

### Key Design Principles (Aligned with Three Pillars)

1. **Modular Architecture** (Pillar 1 - Ease of Use): Features segregated into topic-specific modules for easy management
2. **Intelligent Defaults** (Pillar 1): System auto-detects hardware and suggests optimal configurations
3. **Privilege Separation** (Pillar 2 - Security): Admin/operator privileges separated with polkit integration
4. **Security First** (Pillar 2): Password protection, threat detection, behavioral analysis built-in
5. **Clean Organization** (Pillar 2): STRICT directory structure enforcement, no clutter
6. **Feature Management** (Pillar 1 & 3): Tiered system with educational guidance
7. **Learning Focus** (Pillar 3): Every interaction teaches - wizards, docs, CLI tools

### Documentation Protection

**CRITICAL**: The `docs/dev/` directory contains **PROTECTED** intellectual property:
- **127 comprehensive documentation files** covering all aspects of the project
- **AI context and guidance** to prevent circular fixes and maintain consistency
- **Design philosophy and patterns** that define project identity
- **Historical decisions** explaining WHY things are done certain ways

**See [PROTECTED_DOCS_NOTICE.md](PROTECTED_DOCS_NOTICE.md) and [docs/dev/README_PROTECTED.md](docs/dev/README_PROTECTED.md)**

These files are:
- Proprietary and confidential
- For internal/AI use only
- NOT for public distribution
- Essential for understanding project context

### Directory Structure

```
/
├── configuration.nix           # Main NixOS configuration entry point
├── hardware-configuration.nix  # Auto-generated hardware config
├── flake.nix                   # Nix flake definition
├── install.sh                  # Universal installer script
├── modules/                    # NixOS modules (organized by topic)
│   ├── core/                   # System foundation
│   ├── security/               # Security layers
│   ├── virtualization/         # VM/container features
│   ├── features/               # Feature management
│   ├── monitoring/             # Observability
│   ├── storage-management/     # Storage tiers
│   └── [others]/
├── scripts/                    # Operational scripts
│   ├── hv                      # Unified CLI entry point
│   ├── lib/                    # Shared bash libraries
│   ├── security/               # Security automation
│   └── [wizards]/              # Configuration wizards
├── tools/                      # Rust CLI tools
│   ├── vmctl/                  # VM management CLI
│   └── isoctl/                 # ISO building CLI
├── tests/                      # Test suite
│   ├── integration/            # Integration tests
│   ├── unit/                   # Unit tests
│   └── run_all_tests.sh        # Main test runner
├── docs/                       # Documentation
├── api/                        # GraphQL API (Go)
└── profiles/                   # Pre-configured system variants
```

## Important Files

### Configuration Files

- `configuration.nix` (line 1-100+): Main system configuration with module imports
- `modules/core/options.nix`: Core hypervisor options definitions
- `modules/system-tiers.nix`: System tier definitions (minimal/enhanced/complete)
- `modules/features/feature-manager.nix`: Feature enablement logic

### Critical Security Modules

- `modules/security/password-protection.nix`: Prevents password wipes during rebuilds (CRITICAL)
- `modules/security/privilege-separation.nix`: Admin/operator role separation
- `modules/security/threat-detection.nix`: Behavioral threat detection
- `modules/security/profiles.nix`: Security profile management

### Key Scripts

- `scripts/hv`: Unified CLI dispatcher (routes to wizards and tools)
- `scripts/setup_wizard.sh`: First-boot system configuration
- `scripts/security/security-control.sh`: Security management
- `tests/run_all_tests.sh`: Comprehensive test runner

## Working with NixOS Modules

### Module Structure

Each module follows this pattern:

```nix
{ config, lib, pkgs, ... }:

{
  options.hypervisor.feature = {
    enable = lib.mkEnableOption "description";
    # Additional options...
  };

  config = lib.mkIf config.hypervisor.feature.enable {
    # Configuration when enabled
  };
}
```

### Adding New Features

1. Create module in appropriate `modules/` subdirectory
2. Define options in `options` block
3. Implement configuration in `config` block (use `mkIf` for conditional)
4. Import module in `configuration.nix` or `modules/default.nix`
5. Add feature to `modules/features/feature-categories.nix` if user-facing
6. Update documentation in `docs/`

### Testing Configuration Changes

```bash
# Validate syntax without building
nix eval .#nixosConfigurations.hypervisor-x86_64.config.system.build --apply 'x: "OK"'

# Build but don't activate
sudo nixos-rebuild build

# Build and activate temporarily (revert on reboot)
sudo nixos-rebuild test

# Build and make default
sudo nixos-rebuild switch
```

## Common Development Workflows

### Adding a New VM Management Feature

1. Add option in `modules/vm-management/` or create new module
2. Implement libvirt integration in `modules/virtualization/`
3. Add CLI command in `scripts/hv` or create wizard
4. Write tests in `tests/integration/`
5. Update `docs/user-guides/`

### Implementing Security Feature

1. Create module in `modules/security/`
2. Integrate with existing security profiles (`profiles.nix`)
3. Add polkit rules if needed (`polkit-rules.nix`)
4. Add to security wizard (`scripts/security-configuration-wizard.sh`)
5. Write security tests in `tests/integration-test-security.sh`

### Building ISO

```bash
# Build installation ISO
nix build .#packages.x86_64-linux.iso

# ISO output location
./result/iso/nixos-*.iso

# Custom ISO configuration
# Edit isos/ directory and rebuild
```

## Git Workflow

This repository uses standard git workflows:

```bash
# Create feature branch
git checkout -b feature/description

# Run tests before committing
./tests/run_all_tests.sh

# Commit with descriptive message
git commit -m "module/area: description"

# Example: "security: add capability-based access control"
```

## Troubleshooting

### Build Failures

- Check `nix-build` logs for specific errors
- Verify all module imports are correct in `configuration.nix`
- Ensure no infinite recursion (common with NixOS option definitions)
- Check for duplicate option definitions across modules

### Module Import Errors

- All imports must be relative paths from `configuration.nix`
- Use `./modules/category/module.nix` format
- Verify file exists and has correct syntax

### Test Failures

- CI mode skips tests requiring NixOS/libvirt
- Run `./tests/run_all_tests.sh` locally on NixOS for full validation
- Check test logs for specific assertion failures

## Code Style

### Nix Code

- Use 2-space indentation
- Prefer `lib.mkIf` over raw conditionals
- Use `lib.mkEnableOption` for boolean features
- Add descriptions to all options
- Keep modules focused (single responsibility)

### Bash Scripts

- Use `set -euo pipefail` at script start
- Source shared libraries from `scripts/lib/`
- Implement help text for all user-facing scripts
- Use color codes consistently (defined in `scripts/lib/ui.sh`)
- Validate inputs and provide clear error messages

### Rust Code

- Follow standard Rust conventions (rustfmt)
- Use workspace dependencies (defined in `tools/Cargo.toml`)
- Add comprehensive error handling
- Include CLI help text

## Security Considerations

- **Never commit secrets**: Use NixOS secrets management or external stores
- **Password protection**: The `password-protection.nix` module is CRITICAL - do not remove
- **Privilege separation**: Respect admin/operator boundaries in new features
- **Input validation**: Always validate user inputs in scripts (see `scripts/security/defensive-validation.sh`)
- **Audit logging**: Security-sensitive operations should log to `/var/log/hypervisor/`

## Integration Points

### GraphQL API

- Located in `api/` directory (Go implementation)
- Schema: `api/graphql/schema.graphql`
- Real-time subscriptions for events
- Used by web UI and external integrations

### Web Interface

- Located in `web/` directory
- Integrates with GraphQL API
- Module: `modules/web/`

### Monitoring Stack

- Prometheus + Grafana integration
- Configuration in `modules/monitoring/`
- Metrics exposed for AI anomaly detection
- Setup via `hv monitoring-config` wizard

## Resources

### Public Documentation

- **Quick Start**: `docs/QUICK_START.md` - 5-minute setup guide
- **User Guides**: `docs/user-guides/` - End-user documentation
- **Reference**: `docs/reference/` - Technical details
- **Installation**: `docs/INSTALLATION_GUIDE.md` - Setup procedures

### Protected Development Documentation (docs/dev/)

**MUST READ before any development:**

#### Foundational (Read First)
- **DESIGN_ETHOS.md** - Three-pillar framework (IMMUTABLE)
- **CRITICAL_REQUIREMENTS.md** - Mandatory development requirements
- **AI-LESSONS-LEARNED.md** - Historical mistakes to avoid
- **PROJECT_DEVELOPMENT_HISTORY.md** - Complete historical context

#### AI Guidance
- **AI_ASSISTANT_CONTEXT.md** - Project context for AI agents
- **AI_DOCUMENTATION_PROTOCOL.md** - Documentation maintenance rules
- **AI-Development-Best-Practices.md** - Best practices for AI-assisted development
- **AI-QUICK-REFERENCE.md** - Quick reference for common patterns
- **AI-IP-PROTECTION-RULES.md** - IP protection guidelines

#### Architecture & Design
- **DESIGN_EVOLUTION.md** - Historical design decisions and rationale
- **EDUCATIONAL_PHILOSOPHY.md** - Learning-focused design patterns
- **PRIVILEGE_SEPARATION_MODEL.md** - Security architecture
- **TWO_PHASE_SECURITY_MODEL.md** - Setup vs hardened modes
- **CORRECT_MODULAR_ARCHITECTURE.md** - Module design patterns

#### Implementation Guides
- **COMPLETE_FEATURES_SUMMARY.md** - Full feature catalog
- **FEATURE_MANAGEMENT_GUIDE.md** - Feature system usage
- **CONFIGURATION_MODIFICATION_PROCESS.md** - Safe config changes
- **SCRIPT_STANDARDIZATION_GUIDE.md** - Script development standards

#### Reference
- **COMMON_ISSUES_AND_SOLUTIONS.md** - Troubleshooting guide
- **TROUBLESHOOTING.md** - Comprehensive troubleshooting reference
- **SCRIPT_REFERENCE.md** - Complete script documentation
- **TOOL_GUIDE.md** - CLI tools and usage
- **TESTING_GUIDE.md** - Test development and execution

#### Security
- **THREAT_DEFENSE_SYSTEM.md** - Security architecture overview
- **SECURITY_MODEL.md** - Security model documentation
- **SCALABLE-SECURITY-FRAMEWORK.md** - Security framework architecture
- **SECURITY_CONSIDERATIONS.md** - Security best practices

#### User Guides (in dev for reference)
- **USER_GUIDE.md** - Complete user manual
- **ADMIN_GUIDE.md** - System administration guide
- **AUTOMATION_GUIDE.md** - Automation cookbook
- **HANDS-ON-SECURITY-TUTORIAL.md** - Interactive security learning

**All docs/dev/ files are PROTECTED - see README_PROTECTED.md for access restrictions.**

---

## Decision Framework

Before implementing ANY feature or change:

### 1. Evaluate Against Three Pillars
- [ ] **Ease of Use**: Does this minimize friction?
- [ ] **Security**: Meets security best practices? Risks communicated?
- [ ] **Organization**: Directory structure clean and logical?
- [ ] **Learning**: Can users learn and grow from this?

### 2. Consult Documentation
- [ ] Check CRITICAL_REQUIREMENTS.md for mandatory patterns
- [ ] Review AI-LESSONS-LEARNED.md to avoid past mistakes
- [ ] Check PROJECT_DEVELOPMENT_HISTORY.md for context
- [ ] Review relevant architecture docs (DESIGN_EVOLUTION.md, etc.)

### 3. Ask User
- [ ] Does this align with project vision?
- [ ] Any trade-offs or concerns?
- [ ] Preferred approach if multiple options exist?

### 4. Document
- [ ] Update relevant documentation
- [ ] Add entry to PROJECT_DEVELOPMENT_HISTORY.md if significant
- [ ] Update AI_ASSISTANT_CONTEXT.md if pattern changes

**NEVER skip these steps. They prevent rework and maintain project integrity.**
