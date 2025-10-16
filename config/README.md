# Configuration Files

**Purpose**: All configuration files for Hyper-NixOS - system-wide settings and service-specific configurations

## Structure

```
config/
├── hypervisor.toml           # Primary system configuration
├── module-config-schema.yaml # NixOS module schema
└── services/                 # Service-specific configurations
    └── docker/               # Docker/container configs
        ├── daemon.json       # Docker daemon configuration
        └── security-policy.json # Container security policies
```

## System Configuration

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

## Service Configurations

### services/docker/
Container runtime security and daemon configurations

**Files**:
- `daemon.json` - Docker daemon configuration
  - Log driver settings
  - Storage driver configuration
  - Resource limits (ulimits)
  - Security options (no-new-privileges)
  
- `security-policy.json` - Container security policies
  - Security baselines
  - Policy enforcement rules
  - Container isolation settings

**Usage**:
- Applied during Docker/Podman setup
- Referenced by container security modules
- Security hardening for containerized workloads

## Adding New Service Configurations

When adding a new service:

```
config/services/
├── docker/              # Existing
└── new-service/         # Create subdirectory
    ├── README.md        # Document purpose
    └── config.ext       # Service config files
```

**Guidelines**:
1. One subdirectory per service under `services/`
2. Include README.md explaining purpose and usage
3. Use service-native configuration formats
4. Document how configs are applied
5. Reference from appropriate NixOS modules
6. Update this README with new service info

## Configuration Organization

**Why this structure?**
- ✅ Single source of truth - all configs in one place
- ✅ Clear hierarchy - system vs service separation
- ✅ Easy to navigate - logical subdirectory structure
- ✅ Scalable - easy to add new services
- ✅ Follows conventions - standard config/ directory naming

**Update frequencies**:
- `hypervisor.toml` - Modified by user through wizards/scripts
- `module-config-schema.yaml` - Updated when modules change
- `services/*/` - Service-specific update cycles

**Security contexts**:
- System configs - Read by root, modified by admin tools
- Service configs - Read by respective services, managed by modules

---

*For system configuration guide, see: `/docs/ADMIN_GUIDE.md`*
