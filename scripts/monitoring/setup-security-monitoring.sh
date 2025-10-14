#!/bin/bash
# Setup Security Monitoring Stack
# Configures Prometheus, Grafana, and security metrics collection

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMETHEUS_CONFIG="/etc/prometheus"
GRAFANA_CONFIG="/etc/grafana"
METRICS_DIR="/var/lib/prometheus/node_exporter"

echo -e "${BLUE}Setting up Security Monitoring Stack${NC}"
echo "===================================="

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi
}

# Function to install dependencies
install_dependencies() {
    echo -e "${YELLOW}Installing dependencies...${NC}"
    
    # Update package list
    apt-get update -qq
    
    # Install required packages
    apt-get install -y -qq \
        prometheus \
        prometheus-node-exporter \
        grafana \
        python3-pip \
        jq \
        curl
    
    # Install Python dependencies
    pip3 install -q prometheus_client psutil docker
    
    echo -e "${GREEN}✓ Dependencies installed${NC}"
}

# Function to configure Prometheus
configure_prometheus() {
    echo -e "${YELLOW}Configuring Prometheus...${NC}"
    
    # Create Prometheus rules directory
    mkdir -p "$PROMETHEUS_CONFIG/rules"
    
    # Copy security rules
    cp "$SCRIPT_DIR/security-enhanced-rules.yml" "$PROMETHEUS_CONFIG/rules/"
    
    # Update Prometheus configuration
    cat > "$PROMETHEUS_CONFIG/prometheus.yml" << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'security_.*'
        action: keep

  - job_name: 'docker'
    static_configs:
      - targets: ['localhost:9323']

  - job_name: 'security_metrics'
    static_configs:
      - targets: ['localhost:9100']
    metrics_path: /metrics
    params:
      collect[]:
        - textfile
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: localhost:9100
EOF
    
    # Create textfile collector directory
    mkdir -p "$METRICS_DIR"
    chmod 755 "$METRICS_DIR"
    
    # Restart Prometheus
    systemctl restart prometheus
    systemctl enable prometheus
    
    echo -e "${GREEN}✓ Prometheus configured${NC}"
}

# Function to configure Grafana
configure_grafana() {
    echo -e "${YELLOW}Configuring Grafana...${NC}"
    
    # Start Grafana
    systemctl start grafana-server
    systemctl enable grafana-server
    
    # Wait for Grafana to start
    echo "Waiting for Grafana to start..."
    for i in {1..30}; do
        if curl -s http://localhost:3000/api/health > /dev/null; then
            break
        fi
        sleep 1
    done
    
    # Add Prometheus data source
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "name": "Prometheus",
            "type": "prometheus",
            "url": "http://localhost:9090",
            "access": "proxy",
            "isDefault": true
        }' \
        http://admin:admin@localhost:3000/api/datasources
    
    # Import dashboards
    echo -e "${YELLOW}Importing dashboards...${NC}"
    
    for dashboard in "$SCRIPT_DIR/dashboards"/*.json; do
        if [[ -f "$dashboard" ]]; then
            name=$(basename "$dashboard" .json)
            echo "  Importing $name..."
            
            curl -s -X POST \
                -H "Content-Type: application/json" \
                -d "@$dashboard" \
                http://admin:admin@localhost:3000/api/dashboards/db
        fi
    done
    
    echo -e "${GREEN}✓ Grafana configured${NC}"
}

# Function to setup metrics collection
setup_metrics_collection() {
    echo -e "${YELLOW}Setting up metrics collection...${NC}"
    
    # Copy metrics collector script
    cp "$SCRIPT_DIR/security-metrics-collector.py" /usr/local/bin/
    chmod +x /usr/local/bin/security-metrics-collector.py
    
    # Create systemd service
    cat > /etc/systemd/system/security-metrics-collector.service << 'EOF'
[Unit]
Description=Security Metrics Collector
After=network.target docker.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/security-metrics-collector.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Create timer for periodic collection
    cat > /etc/systemd/system/security-metrics-collector.timer << 'EOF'
[Unit]
Description=Run Security Metrics Collector every minute
Requires=security-metrics-collector.service

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min

[Install]
WantedBy=timers.target
EOF
    
    # Enable and start the service
    systemctl daemon-reload
    systemctl enable security-metrics-collector.timer
    systemctl start security-metrics-collector.timer
    
    echo -e "${GREEN}✓ Metrics collection configured${NC}"
}

# Function to create monitoring alerts
create_alerts() {
    echo -e "${YELLOW}Creating security alerts...${NC}"
    
    cat > "$PROMETHEUS_CONFIG/rules/security-alerts.yml" << 'EOF'
groups:
  - name: security_alerts
    interval: 30s
    rules:
      - alert: LowSecurityScore
        expr: system_security_score < 50
        for: 5m
        labels:
          severity: critical
          category: security
        annotations:
          summary: "System security score is critically low"
          description: "Security score is {{ $value }}%, indicating serious security issues"
      
      - alert: HighRiskContainer
        expr: container_risk_score > 80
        for: 2m
        labels:
          severity: high
          category: container
        annotations:
          summary: "High risk container detected"
          description: "Container {{ $labels.container_name }} has risk score {{ $value }}"
      
      - alert: CriticalVulnerabilities
        expr: container_vulnerabilities_total{severity="critical"} > 0
        for: 1m
        labels:
          severity: critical
          category: vulnerability
        annotations:
          summary: "Critical vulnerabilities detected"
          description: "{{ $value }} critical vulnerabilities in {{ $labels.container_name }}"
      
      - alert: SSHBruteForce
        expr: rate(ssh_login_attempts_total{result="failed"}[5m]) > 0.5
        for: 2m
        labels:
          severity: high
          category: intrusion
        annotations:
          summary: "Possible SSH brute force attack"
          description: "High rate of failed SSH login attempts"
      
      - alert: ManyActiveIncidents
        expr: sum(security_active_incidents) > 10
        for: 5m
        labels:
          severity: high
          category: incident
        annotations:
          summary: "Too many active security incidents"
          description: "{{ $value }} active security incidents require attention"
EOF
    
    # Reload Prometheus configuration
    systemctl reload prometheus
    
    echo -e "${GREEN}✓ Security alerts created${NC}"
}

# Function to setup dashboard automation
setup_dashboard_automation() {
    echo -e "${YELLOW}Setting up dashboard automation...${NC}"
    
    # Create script to update dashboards
    cat > /usr/local/bin/update-security-dashboards.sh << 'EOF'
#!/bin/bash
# Update Grafana dashboards from Git

DASHBOARD_DIR="/opt/security-monitoring/dashboards"
GRAFANA_URL="http://admin:admin@localhost:3000"

# Pull latest dashboards
if [[ -d "$DASHBOARD_DIR/.git" ]]; then
    cd "$DASHBOARD_DIR"
    git pull --quiet
fi

# Import updated dashboards
for dashboard in "$DASHBOARD_DIR"/*.json; do
    if [[ -f "$dashboard" ]]; then
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "@$dashboard" \
            "$GRAFANA_URL/api/dashboards/db" > /dev/null
    fi
done
EOF
    
    chmod +x /usr/local/bin/update-security-dashboards.sh
    
    # Create cron job for daily updates
    echo "0 2 * * * root /usr/local/bin/update-security-dashboards.sh" > /etc/cron.d/update-dashboards
    
    echo -e "${GREEN}✓ Dashboard automation configured${NC}"
}

# Function to test the setup
test_setup() {
    echo -e "${YELLOW}Testing monitoring setup...${NC}"
    
    # Test Prometheus
    if curl -s http://localhost:9090/-/healthy > /dev/null; then
        echo -e "${GREEN}✓ Prometheus is running${NC}"
    else
        echo -e "${RED}✗ Prometheus is not responding${NC}"
    fi
    
    # Test Grafana
    if curl -s http://localhost:3000/api/health | jq -r '.database' | grep -q "ok"; then
        echo -e "${GREEN}✓ Grafana is running${NC}"
    else
        echo -e "${RED}✗ Grafana is not responding${NC}"
    fi
    
    # Test metrics collection
    if systemctl is-active --quiet security-metrics-collector.timer; then
        echo -e "${GREEN}✓ Metrics collector is active${NC}"
    else
        echo -e "${RED}✗ Metrics collector is not running${NC}"
    fi
    
    # Check for metrics file
    if [[ -f "$METRICS_DIR/security_metrics.prom" ]]; then
        echo -e "${GREEN}✓ Security metrics are being collected${NC}"
    else
        echo -e "${YELLOW}! Security metrics file not yet created${NC}"
    fi
}

# Main execution
main() {
    check_root
    
    echo -e "${BLUE}This will set up the complete security monitoring stack${NC}"
    echo "Components to install:"
    echo "  - Prometheus (metrics collection)"
    echo "  - Grafana (visualization)"
    echo "  - Node Exporter (system metrics)"
    echo "  - Security Metrics Collector"
    echo
    read -p "Continue? (y/n) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    
    install_dependencies
    configure_prometheus
    configure_grafana
    setup_metrics_collection
    create_alerts
    setup_dashboard_automation
    
    echo
    test_setup
    
    echo
    echo -e "${GREEN}Security monitoring setup complete!${NC}"
    echo
    echo "Access points:"
    echo "  Prometheus: http://localhost:9090"
    echo "  Grafana: http://localhost:3000 (admin/admin)"
    echo
    echo "Dashboards available:"
    echo "  - Security Overview Dashboard"
    echo "  - Container Security Dashboard"
    echo
    echo "To view logs:"
    echo "  journalctl -u prometheus -f"
    echo "  journalctl -u grafana-server -f"
    echo "  journalctl -u security-metrics-collector -f"
}

# Run main function
main "$@"