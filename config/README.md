# System Configuration Files

**Purpose**: Core system-level configuration files for Hyper-NixOS

## Files

### hypervisor.toml
**Primary system configuration** using TOML format

**Sections**:
- `[system]` - Version, hostname, logging
- `[features]` - UI features, boot behavior
- `[security]` - Security profiles, MFA, auditing
- `[vm]` - Default VM settings, limits, performance
- `[storage]` - Storage paths, quotas
- `[network]` - Bridge, NAT, firewall configuration
- `[backup]` - Backup schedules, retention, encryption
- `[monitoring]` - Metrics, alerts, exporters
- `[api]` - API server, authentication, rate limiting
- `[logging]` - Log levels, rotation
- `[advanced]` - Libvirt, experimental features

**Usage**:
- Referenced by: `modules/core/optimized-system.nix`
- Modified by: System wizards and setup scripts
- Format: TOML (human-readable, type-safe)

### module-config-schema.yaml
**NixOS module configuration schema** using YAML

**Purpose**:
- Defines valid module configuration options
- Schema validation for module parameters
- Documentation reference for module structure

**Usage**:
- Validates module configurations
- Referenced by configuration tools
- Schema enforcement

## Directory Distinction

### `/workspace/config/` (This Directory)
- **Purpose**: System-wide configuration files
- **Scope**: Global hypervisor settings
- **Format**: TOML, YAML (configuration formats)
- **Used by**: NixOS modules, system scripts

### `/workspace/configs/` (Different Directory)
- **Purpose**: Service-specific configurations
- **Scope**: Individual service settings (Docker, etc.)
- **Format**: Service-native formats (JSON, etc.)
- **Used by**: Specific services and integrations

**Why Separate?**
- Clear separation of concerns
- System config vs service config
- Different update frequencies
- Different security contexts

---

*For system configuration guide, see: `/docs/ADMIN_GUIDE.md`*
