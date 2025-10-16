# NixOS Updater - Standalone System Update Tool

**Universal NixOS update/upgrade tool that works on ANY NixOS distribution**

Version: 2.0.0  
License: MIT  
Author: MasterofNull

## 🎯 Features

- ✅ **Universal**: Works on any NixOS system (Hyper-NixOS, vanilla NixOS, custom builds)
- ✅ **Portable**: Single standalone tool, easy to copy and distribute
- ✅ **Smart Detection**: Automatically detects flake vs standard configuration
- ✅ **Safe**: Creates backups, supports rollback, dry-run mode
- ✅ **Flexible**: CLI, wizard, or library for integration
- ✅ **Extensible**: Hook system for custom actions
- ✅ **Updates & Upgrades**: Handles both (same channel updates, channel upgrades)

## 📦 Installation

### Quick Install (Copy to System)
```bash
cd /path/to/Hyper-NixOS/tools/nixos-updater
sudo ./install.sh
```

### Manual Install
```bash
# Copy main script
sudo cp nixos-updater /usr/local/bin/
sudo chmod +x /usr/local/bin/nixos-updater

# Copy library
sudo mkdir -p /usr/local/lib/nixos-updater
sudo cp -r lib/* /usr/local/lib/nixos-updater/

# Create directories
sudo mkdir -p /etc/nixos-updater/hooks
sudo mkdir -p /var/log/nixos-updater
```

### Portable Use (No Installation)
```bash
# Use directly from git clone
cd Hyper-NixOS/tools/nixos-updater
./nixos-updater wizard
```

## 🚀 Usage

### Interactive Wizard (Recommended for New Users)
```bash
nixos-updater wizard
```

### Command Line

**Check for updates**:
```bash
nixos-updater check
```

**Update system (same channel)**:
```bash
nixos-updater update
```

**Upgrade to new channel**:
```bash
# Upgrade to NixOS 24.11
nixos-updater upgrade 24.11

# Upgrade to unstable
nixos-updater upgrade unstable
```

**Rollback**:
```bash
# Rollback to previous generation
nixos-updater rollback

# Rollback to specific generation
nixos-updater rollback 42
```

**View history**:
```bash
nixos-updater history
```

## 🔧 Integration Examples

### Use as Library in Scripts

```bash
#!/usr/bin/env bash

# Source the library
source /usr/local/lib/nixos-updater/lib/nixos-updater-lib.sh

# Use library functions
current_version=$(nixos_get_version)
echo "Current NixOS version: $current_version"

if nixos_is_flake; then
    echo "Using flake-based configuration"
fi

# Perform update
nixos_update_channels
nixos_rebuild_switch
```

### Call from Other Scripts

```bash
#!/usr/bin/env bash
# Your custom update script

# Pre-update tasks
echo "Stopping services..."
systemctl stop my-service

# Call nixos-updater
nixos-updater update

# Post-update tasks
echo "Starting services..."
systemctl start my-service
```

### Integration with Other Wizards

```bash
#!/usr/bin/env bash
# Your setup wizard

show_update_option() {
    echo "Would you like to update the system?"
    read -p "Update now? (y/n): " response
    
    if [[ "$response" == "y" ]]; then
        # Call nixos-updater
        nixos-updater update
    fi
}
```

## 🪝 Hook System

Hooks allow you to run custom actions at specific points in the update process.

### Hook Types

- `pre-check/` - Before checking for updates
- `post-check/` - After checking for updates
- `pre-update/` - Before starting system update
- `post-update/` - After system update completes
- `pre-upgrade/` - Before starting system upgrade
- `post-upgrade/` - After system upgrade completes
- `post-rollback/` - After rollback completes

### Creating Hooks

1. Create executable script in appropriate hooks directory:
```bash
sudo nano /etc/nixos-updater/hooks/post-update/my-hook.sh
sudo chmod +x /etc/nixos-updater/hooks/post-update/my-hook.sh
```

2. Hook script example:
```bash
#!/usr/bin/env bash
# Custom post-update hook

echo "Running custom post-update tasks..."

# Your custom logic here
systemctl restart my-service
notify-send "Update complete!"
```

### Example Hooks

See `hooks-examples/` directory for:
- Configuration backup before update
- Automatic garbage collection after update
- User notifications
- Service restart
- Custom validation

## 📚 Library Functions

When sourcing `nixos-updater-lib.sh`, you get these functions:

### System Information
- `nixos_get_version()` - Get NixOS version
- `nixos_get_codename()` - Get version codename
- `nixos_is_flake()` - Check if using flakes
- `nixos_get_config_path()` - Get configuration path
- `nixos_get_system_type()` - Get config type (flake/standard)

### Generation Management
- `nixos_get_current_generation()` - Current generation number
- `nixos_list_generations()` - List all generations
- `nixos_get_previous_generation()` - Previous generation number
- `nixos_rollback_to_generation(num)` - Rollback to specific generation
- `nixos_rollback_previous()` - Rollback to previous

### Update Functions
- `nixos_update_channels()` - Update channels/flakes
- `nixos_rebuild_switch()` - Rebuild and switch
- `nixos_rebuild_boot()` - Rebuild for next boot
- `nixos_dry_run()` - Test rebuild without applying

### Channel Management
- `nixos_get_available_channels()` - List available channels
- `nixos_is_valid_channel(name)` - Validate channel name
- `nixos_change_channel(name)` - Switch channel

### Maintenance
- `nixos_collect_garbage(days)` - Garbage collection
- `nixos_optimize_store()` - Optimize Nix store
- `nixos_clean_old_generations(keep)` - Remove old generations
- `nixos_check_store_health()` - Verify store integrity

## 🎛️ Configuration

Configuration file: `/etc/nixos-updater/config`

```bash
# Log retention (days)
LOG_RETENTION_DAYS=30

# Automatic garbage collection after update
AUTO_GARBAGE_COLLECT=true
KEEP_GENERATIONS=5

# Backup before major upgrades
AUTO_BACKUP=true

# Hook execution timeout (seconds)
HOOK_TIMEOUT=300
```

## 🔐 Environment Variables

- `NIXOS_UPDATER_LOG_DIR` - Custom log directory
- `NIXOS_UPDATER_HOOKS_DIR` - Custom hooks directory
- `NIXOS_UPDATER_CONFIG` - Custom config file
- `NIXOS_UPDATER_PREFIX` - Installation prefix (default: /usr/local)

## 🤖 Automated Updates

Enable automatic update checks:

```bash
sudo systemctl enable nixos-updater-check.timer
sudo systemctl start nixos-updater-check.timer
```

This will check for updates daily and log results. It does NOT automatically apply updates (you must do that manually).

## 📋 Requirements

- NixOS (any version)
- Bash 4.0+
- Root/sudo access for system updates
- Optional: `jq` for JSON parsing (auto-installed if needed)

## 🔄 Update vs Upgrade

### Update (Same Channel)
```bash
nixos-updater update
```
- Updates packages within current NixOS channel
- Example: 24.05 → 24.05 (newer packages)
- Safe, recommended regularly

### Upgrade (Change Channel)
```bash
nixos-updater upgrade 24.11
```
- Changes NixOS version/channel
- Example: 24.05 → 24.11
- More significant changes, test before production

## 🛡️ Safety Features

- **Dry-run mode**: Test updates before applying
- **Automatic backups**: Configuration backed up before upgrades
- **Generation tracking**: Always can rollback
- **Hook validation**: Hooks timeout after 5 minutes
- **Logging**: All operations logged for audit

## 📖 Examples

### Example 1: Daily Update Check Script
```bash
#!/usr/bin/env bash
# /etc/cron.daily/check-nixos-updates

source /usr/local/lib/nixos-updater/lib/nixos-updater-lib.sh

if nixos_check_for_updates; then
    echo "Updates available!" | mail -s "NixOS Updates" admin@example.com
fi
```

### Example 2: Custom Update Workflow
```bash
#!/usr/bin/env bash
# custom-update.sh

# 1. Check for updates
echo "Checking for updates..."
nixos-updater check

# 2. Confirm with user
read -p "Apply updates? (y/n): " confirm
[[ "$confirm" != "y" ]] && exit 0

# 3. Create backup
echo "Creating backup..."
rsync -av /etc/nixos/ /backup/nixos-$(date +%Y%m%d)/

# 4. Perform update
echo "Updating system..."
nixos-updater update

# 5. Verify services
echo "Checking services..."
systemctl --failed

# 6. Cleanup
echo "Cleaning up..."
nix-collect-garbage -d
```

### Example 3: Integration with Monitoring
```bash
#!/usr/bin/env bash
# Post-update hook for monitoring

# Log to monitoring system
curl -X POST https://monitoring.example.com/api/events \
  -d "{
    \"event\": \"nixos_update\",
    \"hostname\": \"$(hostname)\",
    \"generation\": \"$(nixos_get_current_generation)\",
    \"version\": \"$(nixos_get_version)\"
  }"
```

## 🐛 Troubleshooting

### Update fails
```bash
# Check logs
sudo cat /var/log/nixos-updater/updater-*.log

# Try dry-run
nixos-updater check

# Verify configuration
sudo nixos-rebuild dry-build
```

### Hook fails
```bash
# Test hook manually
sudo /etc/nixos-updater/hooks/post-update/my-hook.sh

# Check hook permissions
ls -la /etc/nixos-updater/hooks/
```

### Rollback needed
```bash
# See available generations
nixos-updater history

# Rollback
nixos-updater rollback
```

## 📞 Support

- **Documentation**: `/usr/share/doc/nixos-updater/`
- **Logs**: `/var/log/nixos-updater/`
- **Configuration**: `/etc/nixos-updater/`
- **GitHub**: https://github.com/MasterofNull/Hyper-NixOS

## 📜 License

MIT License - Free to use, modify, and distribute.

## 🤝 Contributing

Contributions welcome! This tool is designed to benefit the entire NixOS community.

---

**Made with ❤️ for the NixOS community**
