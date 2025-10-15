# Service-Specific Configuration Files

**Purpose**: Configuration files for individual services and integrations

## Structure

### docker/
Container runtime security and daemon configurations

**Files**:
- `daemon.json` - Docker daemon configuration
- `security-policy.json` - Container security policies

**Usage**:
- Applied during Docker/Podman setup
- Referenced by container security modules
- Security hardening for containerized workloads

## Directory Distinction

### `/workspace/configs/` (This Directory)
- **Purpose**: Service-specific configurations
- **Scope**: Individual service settings
- **Format**: Service-native formats (JSON, XML, etc.)
- **Organization**: One subdirectory per service
- **Examples**: Docker, Kubernetes, monitoring services

### `/workspace/config/` (Different Directory)
- **Purpose**: System-wide configuration
- **Scope**: Global hypervisor settings
- **Format**: TOML, YAML (system formats)
- **Used by**: Core system modules

## Adding New Service Configurations

When adding a new service:

```
configs/
├── docker/         # Existing
├── new-service/    # Create subdirectory
│   ├── README.md   # Document purpose
│   └── config.ext  # Service config files
```

**Guidelines**:
1. One subdirectory per service
2. Include README.md explaining purpose
3. Use service-native configuration formats
4. Document how configs are applied
5. Reference from appropriate NixOS modules

---

*For service integration, see: `/docs/guides/SERVICE_INTEGRATION_GUIDE.md`*
