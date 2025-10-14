#!/bin/bash
# shellcheck disable=SC2034,SC2154,SC1091
# Setup script for incident response system

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Setting up Incident Response System${NC}"
echo "===================================="

# Create necessary directories
echo -e "${YELLOW}Creating directories...${NC}"
sudo mkdir -p /var/log/security/{incidents,events,playbooks}
sudo mkdir -p /opt/scripts/security
sudo chmod 755 /var/log/security

# Copy scripts to system location
echo -e "${YELLOW}Installing scripts...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo cp "$SCRIPT_DIR/playbook-executor.py" /opt/scripts/security/
sudo cp "$SCRIPT_DIR/event-monitor.py" /opt/scripts/security/
sudo cp "$SCRIPT_DIR/incident-response-playbooks.yaml" /opt/scripts/security/
sudo cp "$SCRIPT_DIR/test-incident-response.py" /opt/scripts/security/

# Make scripts executable
sudo chmod +x /opt/scripts/security/*.py

# Install Python dependencies
echo -e "${YELLOW}Installing Python dependencies...${NC}"
sudo pip3 install pyyaml aiofiles docker pyinotify || true

# Install systemd service
echo -e "${YELLOW}Installing systemd service...${NC}"
sudo cp "$SCRIPT_DIR/security-monitor.service" /etc/systemd/system/
sudo systemctl daemon-reload

# Create incident response shortcuts
echo -e "${YELLOW}Creating command shortcuts...${NC}"
cat > /tmp/ir-commands.sh << 'EOF'
# Incident Response Commands

# View recent security events
ir-events() {
    local count=${1:-20}
    echo "Recent Security Events:"
    tail -n $count /var/log/security/events.json 2>/dev/null | jq '.' || echo "No events found"
}

# View playbook executions
ir-playbooks() {
    echo "Recent Playbook Executions:"
    cat /var/log/security/playbook_executions.json 2>/dev/null | jq '.' || echo "No executions found"
}

# Test incident response
ir-test() {
    local test_type=${1:-all}
    sudo python3 /opt/scripts/security/test-incident-response.py $test_type
}

# View blocked IPs
ir-blocked() {
    echo "Blocked IPs:"
    sudo iptables -L INPUT -n -v | grep DROP | grep -v "0.0.0.0/0" || echo "No IPs blocked"
}

# Unblock IP
ir-unblock() {
    local ip=$1
    if [[ -z "$ip" ]]; then
        echo "Usage: ir-unblock <IP>"
        return 1
    fi
    
    echo "Unblocking $ip..."
    sudo iptables -D INPUT -s $ip -j DROP 2>/dev/null && echo "Unblocked $ip" || echo "IP not found in block list"
}

# Start/stop monitoring
ir-start() {
    echo "Starting incident response monitoring..."
    sudo systemctl start security-monitor
    sudo systemctl enable security-monitor
    echo "Monitoring started"
}

ir-stop() {
    echo "Stopping incident response monitoring..."
    sudo systemctl stop security-monitor
    echo "Monitoring stopped"
}

ir-status() {
    echo "Incident Response Status:"
    sudo systemctl status security-monitor --no-pager
}

# Manual event trigger
ir-trigger() {
    local event_type=$1
    local source_ip=${2:-"10.10.10.10"}
    
    if [[ -z "$event_type" ]]; then
        echo "Usage: ir-trigger <event_type> [source_ip]"
        echo "Event types: brute_force, port_scan, malware, container_compromise"
        return 1
    fi
    
    echo "Triggering $event_type event..."
    python3 -c "
import asyncio
from datetime import datetime
import sys
sys.path.append('/opt/scripts/security')
from playbook_executor import PlaybookExecutor, SecurityEvent

async def trigger():
    event = SecurityEvent(
        event_type='$event_type',
        source_ip='$source_ip',
        details={'manual_trigger': True}
    )
    
    executor = PlaybookExecutor()
    playbook = executor.match_event_to_playbook(event)
    if playbook:
        await executor.execute_playbook(playbook, event)
        print(f'Executed playbook: {playbook}')
    else:
        print(f'No playbook found for event type: $event_type')

asyncio.run(trigger())
"
}

export -f ir-events
export -f ir-playbooks
export -f ir-test
export -f ir-blocked
export -f ir-unblock
export -f ir-start
export -f ir-stop
export -f ir-status
export -f ir-trigger
EOF

# Add to security aliases
sudo cp /tmp/ir-commands.sh /opt/scripts/security/
echo "source /opt/scripts/security/ir-commands.sh" >> ~/.bashrc

# Create example custom playbook
echo -e "${YELLOW}Creating example custom playbook...${NC}"
cat > /opt/scripts/security/custom-playbooks.yaml << 'EOF'
# Custom Playbooks
# Add your organization-specific playbooks here

playbooks:
  custom_vpn_abuse:
    name: "VPN Abuse Response"
    description: "Response to VPN credential abuse"
    triggers:
      - type: "custom"
        condition: "vpn_multiple_locations"
    actions:
      - name: "suspend_vpn_account"
        type: "command"
        parameters:
          command: "vpnctl suspend {user}"
          
      - name: "notify_user"
        type: "notification"
        parameters:
          severity: "high"
          channels: ["email", "sms"]
          message: "Your VPN account has been suspended due to suspicious activity"

  custom_data_leak:
    name: "Data Leak Response"
    description: "Response to potential data leak"
    triggers:
      - type: "custom"
        condition: "sensitive_data_access"
    actions:
      - name: "revoke_access"
        type: "command"
        parameters:
          command: "access-control revoke {user} {resource}"
          
      - name: "audit_trail"
        type: "forensics"
        parameters:
          collect_access_logs: true
          timeframe: 86400  # 24 hours
EOF

# Test the installation
echo -e "\n${YELLOW}Testing installation...${NC}"

# Check if Python modules can be imported
python3 -c "
import sys
sys.path.append('/opt/scripts/security')
try:
    from playbook_executor import PlaybookExecutor
    from event_monitor import SecurityEventMonitor
    print('✅ Python modules loaded successfully')
except Exception as e:
    print(f'❌ Error loading modules: {e}')
"

# Summary
echo -e "\n${GREEN}Installation Complete!${NC}"
echo "====================="
echo
echo "Available commands:"
echo "  ir-start       - Start monitoring"
echo "  ir-stop        - Stop monitoring"
echo "  ir-status      - Check status"
echo "  ir-events      - View recent events"
echo "  ir-playbooks   - View playbook executions"
echo "  ir-test        - Test incident response"
echo "  ir-blocked     - View blocked IPs"
echo "  ir-unblock <IP> - Unblock an IP"
echo "  ir-trigger <type> - Manually trigger response"
echo
echo "To start monitoring:"
echo "  ir-start"
echo
echo "To test the system:"
echo "  ir-test"
echo
echo "Configuration files:"
echo "  /opt/scripts/security/incident-response-playbooks.yaml"
echo "  /opt/scripts/security/custom-playbooks.yaml"
echo
echo "Logs:"
echo "  /var/log/security/events.json"
echo "  /var/log/security/incidents/"
echo "  journalctl -u security-monitor -f"