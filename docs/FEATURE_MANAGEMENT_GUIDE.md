# Hyper-NixOS Feature Management Guide

## 📋 Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Using the Feature Manager Wizard](#using-the-feature-manager-wizard)
4. [Tier Templates](#tier-templates)
5. [Custom Configurations](#custom-configurations)
6. [Managing Features Post-Installation](#managing-features-post-installation)
7. [Advanced Usage](#advanced-usage)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)

## 🎯 Overview

The Hyper-NixOS Feature Management system allows you to:
- Customize your system configuration at any time
- Use pre-defined tier templates for common use cases
- Create custom feature combinations
- Safely add or remove features with dependency checking
- Export and share configurations

### Key Benefits

- **Flexibility**: Change features without reinstalling
- **Safety**: Automatic dependency resolution and requirement checking
- **Templates**: Pre-configured setups for common scenarios
- **Customization**: Fine-grained control over individual features
- **Portability**: Export/import configurations between systems

## 🚀 Quick Start

### Running the Feature Manager

```bash
# Run as regular user (will prompt for sudo when needed)
/etc/hypervisor/bin/feature-manager

# Or run directly from scripts
bash /workspace/scripts/feature-manager-wizard.sh
```

### Quick Setup Options

1. **Use a Tier Template** - Fastest way to get started
2. **Custom Setup** - Select individual features
3. **Modify Existing** - Adjust current configuration

## 🧙 Using the Feature Manager Wizard

### Main Menu Options

#### 1. Quick Setup - Use Tier Template
Select from pre-configured templates:
- **Minimal**: Basic virtualization (2-4GB RAM)
- **Standard**: Add monitoring & security (4-8GB RAM)
- **Enhanced**: Include web UI & containers (8-16GB RAM)
- **Professional**: AI security & automation (16-32GB RAM)
- **Enterprise**: Full HA clustering (32GB+ RAM)

#### 2. Custom Setup - Select Individual Features
Browse features by category:
- Core System
- Virtualization
- Networking
- Storage
- Security
- Monitoring
- Desktop Environments
- Development Tools
- Enterprise Features

#### 3. View Current Configuration
See:
- Currently enabled features
- Resource requirements
- System compatibility status

#### 4. Feature Information
Browse:
- Complete feature catalog
- Dependencies between features
- Resource requirements
- Configuration examples

#### 5. Export/Import Configuration
- Export current setup to JSON
- Import configuration from file
- Generate shareable configuration codes

#### 6. Apply Configuration
- Test configuration validity
- Create automatic backups
- Apply changes with nixos-rebuild

## 📊 Tier Templates

### Available Templates

#### Standard Tiers

| Tier | RAM | Use Case | Key Features |
|------|-----|----------|--------------|
| **Minimal** | 2-4GB | Learning, testing | Core VM hosting |
| **Standard** | 4-8GB | Small production | + Monitoring, security |
| **Enhanced** | 8-16GB | SMB, development | + Web UI, containers |
| **Professional** | 16-32GB | Enterprise dept | + AI security, automation |
| **Enterprise** | 32GB+ | Service provider | + HA clustering, multi-tenant |

#### Specialized Templates

| Template | RAM | Use Case | Focus |
|----------|-----|----------|-------|
| **Developer** | 16GB | Development workstation | Desktop, tools, containers |
| **Security-Focused** | 12GB | High-security environment | Maximum hardening, AI detection |
| **Lab** | 8GB | Home lab/testing | Lightweight desktop, templates |

### Customizing Templates

After selecting a template, you can:
1. Use as-is
2. Add additional features
3. Remove unwanted features
4. Save as custom template

Example:
```bash
# Select "Enhanced" template
# Then add "ai-security" feature
# Remove "web-dashboard" if not needed
```

## 🔧 Custom Configurations

### Building from Scratch

1. Start with core features
2. Add virtualization components
3. Select networking options
4. Choose storage backends
5. Add security layers
6. Include monitoring/management
7. Optional: Add desktop environment

### Feature Selection Tips

- **Check Dependencies**: Some features require others
- **Monitor RAM Usage**: Keep track of total requirements
- **Consider Use Case**: Don't over-provision
- **Test Incrementally**: Add features gradually

### Creating Custom Templates

Save your configuration as a reusable template:

```nix
# In /etc/nixos/custom-templates.nix
hypervisor.tierTemplates.customTemplates = {
  myWebServer = {
    description = "Optimized web hosting setup";
    baseTemplate = "standard";
    addFeatures = [ "web-dashboard" "container-support" "ssl-termination" ];
    removeFeatures = [ "desktop-kde" ];
  };
};
```

## 🔄 Managing Features Post-Installation

### Adding Features

```bash
# Run the wizard
/etc/hypervisor/bin/feature-manager

# Select "Custom Setup"
# Navigate to desired category
# Enable new features
# Apply configuration
```

### Removing Features

```bash
# Same process, but toggle features off
# Wizard handles dependency checking
# Warns about dependent features
```

### Changing Tiers

```bash
# Run: /etc/hypervisor/bin/reconfigure-tier
# Or use feature manager to switch templates
```

### Updating Feature Configuration

Edit feature-specific settings:

```nix
# /etc/nixos/hypervisor-features.nix
hypervisor.features.ai-security = {
  sensitivity = "high";  # Was "balanced"
  updateInterval = "1h"; # Was "6h"
};
```

## 🎓 Advanced Usage

### Command-Line Management

```bash
# List available templates
hv-template list

# Show template details
hv-template show enhanced

# Check requirements
hv-template check professional

# Apply template directly (bypass wizard)
hv-apply-template enterprise
```

### Scripted Configuration

```bash
#!/bin/bash
# automated-setup.sh

# Export current config
/etc/hypervisor/bin/feature-manager --export > base.json

# Modify JSON
jq '.features += ["ai-security", "clustering"]' base.json > new.json

# Import and apply
/etc/hypervisor/bin/feature-manager --import new.json --apply
```

### Feature Profiles

Create environment-specific profiles:

```nix
# profiles/production.nix
{
  hypervisor.featureProfiles.production = {
    requiredFeatures = [
      "monitoring" "alerting" "backup-enterprise"
      "security-base" "audit-logging" "compliance"
    ];
    forbiddenFeatures = [
      "desktop-kde" "desktop-gnome" "dev-tools"
    ];
  };
}
```

### Integration with Configuration Management

```yaml
# Ansible playbook
- name: Configure Hyper-NixOS features
  hosts: hypervisors
  tasks:
    - name: Apply enterprise template
      command: |
        /etc/hypervisor/bin/feature-manager \
          --template enterprise \
          --add-features custom-monitoring,special-auth \
          --remove-features desktop-kde \
          --non-interactive \
          --apply
```

## 🔍 Troubleshooting

### Common Issues

#### "Feature won't enable"
- Check dependencies: `hv-feature deps <feature>`
- Verify resources: `hv-feature check-resources`
- Review logs: `journalctl -u hypervisor-features`

#### "Configuration won't apply"
- Test build: `nixos-rebuild dry-build`
- Check syntax: `nix-instantiate --parse /etc/nixos/configuration.nix`
- Restore backup: `hv-feature restore-backup`

#### "System runs out of resources"
- Review enabled features: `hv-feature list --enabled`
- Check resource usage: `hv-feature resource-report`
- Disable unnecessary features

#### "Features conflict"
- Check compatibility: `hv-feature compat-check`
- Review feature exclusions
- Use tier templates as baseline

### Recovery Procedures

```bash
# Boot to previous configuration
# Select previous generation in bootloader

# Or restore backup
cd /etc/nixos
sudo cp backups/config-20240114-120000.nix configuration.nix
sudo cp backups/config-20240114-120000-features.nix hypervisor-features.nix
sudo nixos-rebuild switch

# Emergency minimal mode
sudo nixos-rebuild switch --fast -I nixos-config=/etc/nixos/configuration-minimal.nix
```

## 💡 Best Practices

### Planning

1. **Start Small**: Begin with minimal/standard tier
2. **Document Changes**: Keep notes on why features were added
3. **Test First**: Use VM or test system before production
4. **Monitor Impact**: Watch resource usage after changes

### Security

1. **Regular Updates**: Keep security features current
2. **Minimal Attack Surface**: Only enable needed features
3. **Audit Regularly**: Review enabled features quarterly
4. **Use Templates**: Tested combinations are safer

### Performance

1. **Resource Planning**: Plan for 20% overhead
2. **Incremental Changes**: Add features one at a time
3. **Monitor Metrics**: Use built-in monitoring
4. **Optimize First**: Tune before adding features

### Maintenance

1. **Keep Backups**: Feature manager auto-backups
2. **Document Custom**: Record custom configurations
3. **Update Templates**: Refresh templates with updates
4. **Review Logs**: Check for feature warnings

## 📚 Examples

### Example 1: Development Setup

```bash
# Start with developer template
# Add specific tools
features="rust-dev python-dev nodejs container-support"
# Remove unwanted desktop
remove="desktop-gnome"
# Apply configuration
```

### Example 2: Secure Web Server

```bash
# Base: security-focused template
# Add: web-dashboard, ssl-termination, container-support
# Add: monitoring, alerting, backup-enterprise
# Configure: High sensitivity for AI security
```

### Example 3: Migration from Standard to Professional

```bash
# Export current config
# Switch to professional template
# Merge custom features from export
# Verify all dependencies met
# Apply with testing
```

## 🆘 Getting Help

### Built-in Help
```bash
# Wizard help
/etc/hypervisor/bin/feature-manager --help

# Feature information
hv-feature info <feature-name>

# Template details
hv-template show <template-name>
```

### Resources
- Feature Catalog: `/docs/FEATURE_CATALOG.md`
- System Requirements: `/docs/SYSTEM_REQUIREMENTS.md`
- Troubleshooting: `/docs/TROUBLESHOOTING.md`

### Support
- GitHub Issues: Report problems
- Community Forum: Ask questions
- Documentation: Check guides

## 🎁 Tips & Tricks

1. **Quick Toggle**: Use space bar to toggle features in wizard
2. **Batch Operations**: Select multiple features before applying
3. **Dry Run**: Always test with `--dry-run` first
4. **Feature Search**: Use `/` to search in feature list
5. **Quick Save**: Export config regularly for easy rollback

Remember: The feature management system is designed to be safe and user-friendly. Don't hesitate to experiment - backups are automatic!