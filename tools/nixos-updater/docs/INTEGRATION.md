# NixOS Updater Integration Guide

Complete guide for integrating nixos-updater into your own tools, scripts, and workflows.

## 🎯 Integration Methods

nixos-updater can be integrated in three ways:

1. **Library Functions** - Source the library and call functions
2. **CLI Commands** - Execute as external command
3. **Hooks** - Extend updater with custom actions

## 📚 Method 1: Library Integration

### Basic Library Usage

```bash
#!/usr/bin/env bash
# Your script

# Source the library
source /usr/local/lib/nixos-updater/lib/nixos-updater-lib.sh

# Now you have access to all functions
current_gen=$(nixos_get_current_generation)
version=$(nixos_get_version)

echo "NixOS $version (generation $current_gen)"
```

### Integration Example: System Setup Wizard

```bash
#!/usr/bin/env bash
# setup-wizard.sh - Integrates system updates

source /usr/local/lib/nixos-updater/lib/nixos-updater-lib.sh

setup_wizard() {
    echo "=== System Setup Wizard ==="
    echo
    
    # Show current system info
    echo "Current System:"
    echo "  Version: $(nixos_get_version)"
    echo "  Type: $(nixos_get_system_type)"
    echo "  Generation: $(nixos_get_current_generation)"
    echo
    
    # Offer update
    read -p "Would you like to update the system? (y/n): " response
    if [[ "$response" == "y" ]]; then
        echo "Checking for updates..."
        if nixos_check_for_updates; then
            echo "Updates available!"
            read -p "Apply now? (y/n): " apply
            if [[ "$apply" == "y" ]]; then
                echo "Updating channels..."
                nixos_update_channels
                
                echo "Rebuilding system..."
                nixos_rebuild_switch
                
                echo "✓ System updated to generation $(nixos_get_current_generation)"
            fi
        else
            echo "System is up to date!"
        fi
    fi
    
    # Continue with other setup tasks...
}

setup_wizard
```

### Integration Example: Maintenance Script

```bash
#!/usr/bin/env bash
# system-maintenance.sh

source /usr/local/lib/nixos-updater/lib/nixos-updater-lib.sh

perform_maintenance() {
    echo "Starting system maintenance..."
    
    # 1. Update system
    echo "→ Updating system..."
    nixos_update_channels
    nixos_rebuild_switch
    
    # 2. Cleanup
    echo "→ Cleaning old generations (keeping 5)..."
    nixos_clean_old_generations 5
    
    # 3. Garbage collection
    echo "→ Running garbage collection..."
    nixos_collect_garbage 7
    
    # 4. Store optimization
    echo "→ Optimizing Nix store..."
    nixos_optimize_store
    
    # 5. Health check
    echo "→ Verifying store integrity..."
    nixos_check_store_health
    
    echo "✓ Maintenance complete!"
    echo "  Final generation: $(nixos_get_current_generation)"
}

perform_maintenance
```

## 🖥️ Method 2: CLI Integration

### Execute as External Command

```bash
#!/usr/bin/env bash
# Your deployment script

echo "Deploying application..."

# Update system first
if nixos-updater check; then
    echo "Updates available, applying..."
    nixos-updater update
fi

# Deploy your application
./deploy-app.sh

echo "Deployment complete!"
```

### Capture Output

```bash
#!/usr/bin/env bash
# update-with-logging.sh

LOG_FILE="/var/log/my-updates.log"

echo "=== Update started $(date) ===" >> "$LOG_FILE"

# Capture output
if nixos-updater update 2>&1 | tee -a "$LOG_FILE"; then
    echo "✓ Update successful" >> "$LOG_FILE"
    
    # Send success notification
    notify-send "System Updated" "NixOS update completed successfully"
else
    echo "✗ Update failed" >> "$LOG_FILE"
    
    # Send failure notification
    notify-send -u critical "Update Failed" "Check logs at $LOG_FILE"
fi

echo "=== Update finished $(date) ===" >> "$LOG_FILE"
```

### Non-Interactive Automation

```bash
#!/usr/bin/env bash
# automated-updates.sh

# Set non-interactive mode
export NIXOS_UPDATER_NONINTERACTIVE=1

# Perform update without prompts
nixos-updater update || {
    # Rollback on failure
    nixos-updater rollback
    exit 1
}
```

## 🪝 Method 3: Hooks Integration

### Creating Custom Hooks

Hooks run at specific points in the update process. Perfect for custom actions.

#### Pre-Update Hook Example

```bash
#!/usr/bin/env bash
# /etc/nixos-updater/hooks/pre-update/stop-services.sh

echo "Stopping application services before update..."

systemctl stop myapp.service
systemctl stop database.service

# Create marker file
touch /var/run/services-stopped-for-update

echo "✓ Services stopped"
```

#### Post-Update Hook Example

```bash
#!/usr/bin/env bash
# /etc/nixos-updater/hooks/post-update/restart-services.sh

BACKUP_GEN=$1  # Previous generation passed as argument

echo "Restarting application services after update..."

if [[ -f /var/run/services-stopped-for-update ]]; then
    systemctl start database.service
    systemctl start myapp.service
    rm /var/run/services-stopped-for-update
    
    echo "✓ Services restarted"
else
    echo "⚠ Services were not stopped, skipping restart"
fi

# Log the update
logger -t myapp "System updated from generation $BACKUP_GEN to $(nixos-rebuild list-generations | tail -1 | awk '{print $1}')"
```

#### Hook with External Integration

```bash
#!/usr/bin/env bash
# /etc/nixos-updater/hooks/post-update/notify-monitoring.sh

BACKUP_GEN=$1
NEW_GEN=$(nixos-rebuild list-generations | tail -1 | awk '{print $1}')
HOSTNAME=$(hostname)
VERSION=$(nixos-version)

# Send to monitoring system
curl -X POST https://monitoring.example.com/api/events \
  -H "Content-Type: application/json" \
  -d "{
    \"event_type\": \"nixos_update\",
    \"hostname\": \"$HOSTNAME\",
    \"previous_generation\": \"$BACKUP_GEN\",
    \"new_generation\": \"$NEW_GEN\",
    \"version\": \"$VERSION\",
    \"timestamp\": \"$(date -Iseconds)\"
  }"

echo "✓ Monitoring system notified"
```

## 🔧 Advanced Integration Patterns

### Pattern 1: Conditional Updates

```bash
#!/usr/bin/env bash
source /usr/local/lib/nixos-updater/lib/nixos-updater-lib.sh

# Only update if on specific channel
current_version=$(nixos_get_version)

if [[ "$current_version" == "24.05" ]]; then
    echo "Updating stable channel..."
    nixos_update_channels
    nixos_rebuild_switch
else
    echo "Not on stable channel, skipping update"
fi
```

### Pattern 2: Multi-System Updates

```bash
#!/usr/bin/env bash
# update-all-systems.sh

SYSTEMS=(
    "server01"
    "server02"
    "workstation01"
)

for system in "${SYSTEMS[@]}"; do
    echo "Updating $system..."
    
    ssh "$system" "sudo nixos-updater update" || {
        echo "✗ Failed to update $system"
        continue
    }
    
    echo "✓ Updated $system"
done
```

### Pattern 3: Staged Rollout

```bash
#!/usr/bin/env bash
source /usr/local/lib/nixos-updater/lib/nixos-updater-lib.sh

# Stage 1: Test on one system
echo "Stage 1: Updating test system..."
ssh test-server "sudo nixos-updater update"

# Wait and verify
sleep 300
if ssh test-server "systemctl is-system-running"; then
    echo "✓ Test system healthy"
else
    echo "✗ Test system unhealthy, aborting rollout"
    ssh test-server "sudo nixos-updater rollback"
    exit 1
fi

# Stage 2: Update production systems
echo "Stage 2: Updating production systems..."
for server in prod-{01..10}; do
    ssh "$server" "sudo nixos-updater update"
    sleep 60  # Stagger updates
done
```

### Pattern 4: Update with Validation

```bash
#!/usr/bin/env bash
source /usr/local/lib/nixos-updater/lib/nixos-updater-lib.sh

# Backup current state
BACKUP_GEN=$(nixos_get_current_generation)

# Perform update
echo "Updating system..."
nixos_update_channels
nixos_rebuild_switch

# Validation tests
echo "Running validation tests..."

tests_passed=true

# Test 1: Check critical services
for service in sshd nginx postgresql; do
    if ! systemctl is-active "$service" >/dev/null; then
        echo "✗ Service $service not running"
        tests_passed=false
    fi
done

# Test 2: Check network
if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "✗ Network connectivity failed"
    tests_passed=false
fi

# Test 3: Custom application test
if ! curl -f http://localhost/health >/dev/null 2>&1; then
    echo "✗ Application health check failed"
    tests_passed=false
fi

# Rollback if tests failed
if [[ "$tests_passed" == "false" ]]; then
    echo "⚠ Validation failed, rolling back..."
    nixos_rollback_to_generation "$BACKUP_GEN"
    exit 1
fi

echo "✓ All validation tests passed"
```

## 📡 Integration with CI/CD

### GitLab CI Example

```yaml
# .gitlab-ci.yml

stages:
  - test
  - deploy
  - update

test:
  stage: test
  script:
    - nix-build
    - nix-shell --run "make test"

deploy:
  stage: deploy
  script:
    - ./deploy.sh

update-systems:
  stage: update
  only:
    - main
  script:
    - |
      for host in prod-{01..05}; do
        ssh $host "sudo nixos-updater update"
      done
  when: manual
```

### GitHub Actions Example

```yaml
# .github/workflows/update-systems.yml

name: Update NixOS Systems

on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly on Sunday 2 AM
  workflow_dispatch:      # Manual trigger

jobs:
  update:
    runs-on: self-hosted
    strategy:
      matrix:
        server: [server01, server02, server03]
    steps:
      - name: Update ${{ matrix.server }}
        run: |
          ssh ${{ matrix.server }} "sudo nixos-updater update"
          
      - name: Verify
        run: |
          ssh ${{ matrix.server }} "systemctl is-system-running"
          
      - name: Rollback on failure
        if: failure()
        run: |
          ssh ${{ matrix.server }} "sudo nixos-updater rollback"
```

## 🐍 Integration with Python

```python
#!/usr/bin/env python3
# update-manager.py

import subprocess
import json
from datetime import datetime

class NixOSUpdater:
    def __init__(self):
        self.log_file = "/var/log/update-manager.log"
    
    def check_updates(self):
        """Check for available updates"""
        result = subprocess.run(
            ["nixos-updater", "check"],
            capture_output=True,
            text=True
        )
        return result.returncode == 0
    
    def perform_update(self):
        """Perform system update"""
        print("Starting system update...")
        
        result = subprocess.run(
            ["nixos-updater", "update"],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            self.log_success("Update completed successfully")
            return True
        else:
            self.log_error(f"Update failed: {result.stderr}")
            return False
    
    def rollback(self):
        """Rollback to previous generation"""
        result = subprocess.run(
            ["nixos-updater", "rollback"],
            capture_output=True,
            text=True
        )
        return result.returncode == 0
    
    def log_success(self, message):
        self._log("SUCCESS", message)
    
    def log_error(self, message):
        self._log("ERROR", message)
    
    def _log(self, level, message):
        timestamp = datetime.now().isoformat()
        log_entry = f"[{timestamp}] [{level}] {message}\n"
        
        with open(self.log_file, "a") as f:
            f.write(log_entry)

# Usage
if __name__ == "__main__":
    updater = NixOSUpdater()
    
    if updater.check_updates():
        print("Updates available!")
        if updater.perform_update():
            print("✓ Update successful")
        else:
            print("✗ Update failed, rolling back...")
            updater.rollback()
    else:
        print("System is up to date")
```

## 🔗 API Integration

If you're building a web interface or API for system management:

```python
from flask import Flask, jsonify
import subprocess

app = Flask(__name__)

@app.route('/api/system/check-updates', methods=['GET'])
def check_updates():
    result = subprocess.run(
        ["nixos-updater", "check"],
        capture_output=True,
        text=True
    )
    
    return jsonify({
        "updates_available": result.returncode == 0,
        "output": result.stdout
    })

@app.route('/api/system/update', methods=['POST'])
def perform_update():
    result = subprocess.run(
        ["nixos-updater", "update"],
        capture_output=True,
        text=True
    )
    
    return jsonify({
        "success": result.returncode == 0,
        "output": result.stdout,
        "error": result.stderr if result.returncode != 0 else None
    })

@app.route('/api/system/generations', methods=['GET'])
def list_generations():
    result = subprocess.run(
        ["nixos-updater", "history"],
        capture_output=True,
        text=True
    )
    
    return jsonify({
        "generations": result.stdout.split('\n')
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

## 📝 Best Practices

### 1. Always Log Operations
```bash
nixos-updater update 2>&1 | tee -a /var/log/my-updates.log
```

### 2. Test Before Production
```bash
# Test in dry-run or on test system first
nixos-rebuild dry-build
```

### 3. Use Hooks for Custom Logic
Don't modify the updater itself, use hooks for customization.

### 4. Handle Failures Gracefully
```bash
if ! nixos-updater update; then
    nixos-updater rollback
    notify_admin "Update failed and was rolled back"
fi
```

### 5. Document Integration Points
Always document how your tool integrates with nixos-updater.

## 🆘 Troubleshooting Integration

### Library Not Found
```bash
# Ensure library is sourced with full path
source /usr/local/lib/nixos-updater/lib/nixos-updater-lib.sh
```

### Permission Denied
```bash
# Most operations require root
sudo nixos-updater update
```

### Hook Not Executing
```bash
# Check hook permissions
chmod +x /etc/nixos-updater/hooks/post-update/my-hook.sh

# Test hook manually
sudo /etc/nixos-updater/hooks/post-update/my-hook.sh
```

---

For more examples, see the `examples/` directory in the nixos-updater repository.
