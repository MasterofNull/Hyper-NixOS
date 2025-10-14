#!/bin/bash
# Security Monitoring Setup Script
# Sets up basic security monitoring inspired by MaxOS patterns
# Version: 1.0

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Security Monitoring Setup ===${NC}"
echo -e "${BLUE}Setting up monitoring inspired by MaxOS patterns...${NC}"
echo

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}This script should not be run as root!${NC}"
   echo "Please run as a regular user with sudo privileges."
   exit 1
fi

# Create monitoring directory structure
MONITOR_DIR="$HOME/security-monitoring"
mkdir -p $MONITOR_DIR/{configs,scripts,logs,alerts,playbooks}

echo -e "${GREEN}✓ Created monitoring directory structure${NC}"

# ============================================
# 1. Create Prometheus configuration
# ============================================
echo -e "\n${YELLOW}Creating Prometheus configuration...${NC}"

cat > $MONITOR_DIR/configs/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

rule_files:
  - "security_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'docker'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx-exporter:9113']
EOF

# ============================================
# 2. Create security alert rules
# ============================================
cat > $MONITOR_DIR/configs/security_rules.yml << 'EOF'
groups:
  - name: security_alerts
    interval: 30s
    rules:
      # High CPU usage (possible crypto mining)
      - alert: HighCPUUsage
        expr: 100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% (current value: {{ $value }}%)"

      # SSH brute force attempts
      - alert: SSHBruteForce
        expr: rate(node_systemd_unit_failed_total{name="ssh.service"}[5m]) > 5
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Possible SSH brute force attack"
          description: "Multiple SSH login failures detected"

      # Disk space low
      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space"
          description: "Disk space is below 10% on root partition"

      # Unusual network traffic
      - alert: UnusualNetworkTraffic
        expr: rate(node_network_receive_bytes_total[5m]) > 100000000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Unusual network traffic detected"
          description: "High network traffic detected (possible data exfiltration)"

      # New open port detected
      - alert: NewOpenPort
        expr: delta(node_sockstat_TCP_alloc[1h]) > 0
        for: 5m
        labels:
          severity: info
        annotations:
          summary: "New TCP port opened"
          description: "A new TCP port has been opened on the system"
EOF

# ============================================
# 3. Create Docker Compose for monitoring stack
# ============================================
echo -e "\n${YELLOW}Creating Docker Compose configuration...${NC}"

cat > $MONITOR_DIR/docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./configs/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./configs/security_rules.yml:/etc/prometheus/security_rules.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    restart: unless-stopped
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=SecurePass123!
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource,grafana-worldmap-panel
    volumes:
      - grafana_data:/var/lib/grafana
      - ./configs/grafana-datasources.yml:/etc/grafana/provisioning/datasources/prometheus.yml
      - ./configs/grafana-dashboards.yml:/etc/grafana/provisioning/dashboards/dashboards.yml
      - ./dashboards:/var/lib/grafana/dashboards
    restart: unless-stopped
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    restart: unless-stopped
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    devices:
      - /dev/kmsg
    restart: unless-stopped
    networks:
      - monitoring

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./configs/alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    restart: unless-stopped
    networks:
      - monitoring

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:

networks:
  monitoring:
    driver: bridge
EOF

# ============================================
# 4. Create Grafana datasource configuration
# ============================================
cat > $MONITOR_DIR/configs/grafana-datasources.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

# ============================================
# 5. Create Alertmanager configuration
# ============================================
cat > $MONITOR_DIR/configs/alertmanager.yml << 'EOF'
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'default'
  routes:
    - match:
        severity: critical
      receiver: critical-alerts
      continue: true

receivers:
  - name: 'default'
    webhook_configs:
      - url: 'http://localhost:5001/webhook'
        send_resolved: true

  - name: 'critical-alerts'
    webhook_configs:
      - url: 'http://localhost:5001/critical'
        send_resolved: true

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
EOF

# ============================================
# 6. Create basic security dashboard
# ============================================
echo -e "\n${YELLOW}Creating Grafana security dashboard...${NC}"

mkdir -p $MONITOR_DIR/dashboards

cat > $MONITOR_DIR/configs/grafana-dashboards.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'Security Dashboards'
    orgId: 1
    folder: 'Security'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

# Create security dashboard JSON
cat > $MONITOR_DIR/dashboards/security-overview.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Security Overview",
    "tags": ["security", "monitoring"],
    "timezone": "browser",
    "panels": [
      {
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "id": 1,
        "title": "SSH Login Attempts",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(node_systemd_unit_failed_total{name=\"ssh.service\"}[5m])",
            "legendFormat": "Failed SSH Attempts"
          }
        ]
      },
      {
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "id": 2,
        "title": "Network Traffic",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(node_network_receive_bytes_total[5m])",
            "legendFormat": "Inbound {{device}}"
          },
          {
            "expr": "rate(node_network_transmit_bytes_total[5m])",
            "legendFormat": "Outbound {{device}}"
          }
        ]
      },
      {
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
        "id": 3,
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "CPU Usage %"
          }
        ]
      },
      {
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
        "id": 4,
        "title": "Open Connections",
        "type": "graph",
        "targets": [
          {
            "expr": "node_sockstat_TCP_alloc",
            "legendFormat": "TCP Connections"
          }
        ]
      }
    ]
  }
}
EOF

# ============================================
# 7. Create log monitoring script
# ============================================
echo -e "\n${YELLOW}Creating log monitoring script...${NC}"

cat > $MONITOR_DIR/scripts/log-monitor.sh << 'EOF'
#!/bin/bash
# Real-time log monitoring for security events

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Log file locations
AUTH_LOG="/var/log/auth.log"
SYSLOG="/var/log/syslog"
NGINX_LOG="/var/log/nginx/access.log"

echo "Starting security log monitoring..."
echo "Press Ctrl+C to stop"
echo

# Monitor authentication logs
monitor_auth() {
    echo -e "${YELLOW}=== Authentication Events ===${NC}"
    sudo tail -f $AUTH_LOG | while read line; do
        if echo "$line" | grep -q "Failed password"; then
            echo -e "${RED}[ALERT] Failed login attempt:${NC} $line"
        elif echo "$line" | grep -q "Accepted publickey"; then
            echo -e "[INFO] SSH login: $line"
        elif echo "$line" | grep -q "sudo"; then
            echo -e "[SUDO] $line"
        fi
    done
}

# Monitor system logs
monitor_system() {
    echo -e "${YELLOW}=== System Events ===${NC}"
    sudo tail -f $SYSLOG | while read line; do
        if echo "$line" | grep -qE "error|critical|alert|emergency"; then
            echo -e "${RED}[SYSTEM]${NC} $line"
        fi
    done
}

# Monitor web logs (if nginx exists)
monitor_web() {
    if [ -f "$NGINX_LOG" ]; then
        echo -e "${YELLOW}=== Web Access Events ===${NC}"
        sudo tail -f $NGINX_LOG | while read line; do
            if echo "$line" | grep -qE "404|403|500|502"; then
                echo -e "${RED}[WEB ERROR]${NC} $line"
            elif echo "$line" | grep -qE "\.php|\.asp|\.jsp|/admin|/wp-admin"; then
                echo -e "${YELLOW}[WEB SCAN]${NC} $line"
            fi
        done
    fi
}

# Run all monitors in parallel
monitor_auth &
monitor_system &
monitor_web &

# Wait for all background processes
wait
EOF

chmod +x $MONITOR_DIR/scripts/log-monitor.sh

# ============================================
# 8. Create setup completion script
# ============================================
cat > $MONITOR_DIR/start-monitoring.sh << 'EOF'
#!/bin/bash
# Start the security monitoring stack

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR

echo "Starting security monitoring stack..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "docker-compose is not installed. Please install docker-compose first."
    exit 1
fi

# Start the monitoring stack
docker-compose up -d

echo
echo "Monitoring stack is starting..."
echo
echo "Access points:"
echo "- Prometheus: http://localhost:9090"
echo "- Grafana: http://localhost:3000 (admin/SecurePass123!)"
echo "- Node Exporter: http://localhost:9100/metrics"
echo "- cAdvisor: http://localhost:8080"
echo "- Alertmanager: http://localhost:9093"
echo
echo "To view logs: docker-compose logs -f"
echo "To stop: docker-compose down"
echo
echo "To start log monitoring: ./scripts/log-monitor.sh"
EOF

chmod +x $MONITOR_DIR/start-monitoring.sh

# ============================================
# 9. Create quick deployment script
# ============================================
cat > $MONITOR_DIR/quick-deploy.sh << 'EOF'
#!/bin/bash
# Quick deployment of security monitoring

echo "Quick Security Monitoring Deployment"
echo "===================================="
echo

# Install required packages
echo "Installing required packages..."
if command -v apt-get &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y curl wget git
elif command -v yum &> /dev/null; then
    sudo yum install -y curl wget git
fi

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo "Please log out and back in for Docker permissions to take effect"
fi

# Install docker-compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo "Installing docker-compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

echo
echo "Setup complete! Run ./start-monitoring.sh to start the monitoring stack."
EOF

chmod +x $MONITOR_DIR/quick-deploy.sh

# ============================================
# Summary
# ============================================
echo
echo -e "${GREEN}✓ Security monitoring setup complete!${NC}"
echo
echo -e "${BLUE}Created files:${NC}"
echo "  - Prometheus configuration"
echo "  - Security alert rules"
echo "  - Docker Compose stack"
echo "  - Grafana dashboards"
echo "  - Log monitoring scripts"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. cd $MONITOR_DIR"
echo "2. Review and customize configurations"
echo "3. Run: ./quick-deploy.sh (to install dependencies)"
echo "4. Run: ./start-monitoring.sh (to start monitoring)"
echo
echo -e "${BLUE}Security monitoring directory: $MONITOR_DIR${NC}"