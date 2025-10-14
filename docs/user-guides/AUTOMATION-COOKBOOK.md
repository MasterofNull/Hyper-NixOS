# Security Automation Cookbook 🚀

## Transform Hours of Work into Minutes!

This cookbook contains ready-to-use automation recipes that will save you time and improve your security posture. Each recipe includes explanations for beginners and customization tips for advanced users.

## Table of Contents
1. [Getting Started with Automation](#getting-started-with-automation)
2. [SSH Automation Recipes](#ssh-automation-recipes)
3. [Docker Automation Recipes](#docker-automation-recipes)
4. [Parallel Processing Recipes](#parallel-processing-recipes)
5. [Security Scanning Automation](#security-scanning-automation)
6. [Monitoring and Alerting](#monitoring-and-alerting)
7. [Custom Workflows](#custom-workflows)

---

## Getting Started with Automation

### What is Automation?
Think of automation like setting up dominoes - you push the first one, and the rest happen automatically!

### Your First Automation

Let's start simple - automate your morning security check:

```bash
#!/bin/bash
# morning-check.sh - Your automated security assistant

echo "Good morning! Running security checks..."
echo "======================================"

# Check 1: Who logged in overnight?
echo "📊 Overnight SSH activity:"
ssh_login_history 20 | grep "$(date +%Y-%m-%d)"

# Check 2: System health
echo -e "\n💓 System health:"
security-status | grep -E "active|Failed|Score"

# Check 3: Any alerts?
echo -e "\n🚨 Recent alerts:"
tail -5 /var/log/security/alerts.log 2>/dev/null || echo "No alerts!"

echo -e "\n✅ Morning check complete!"
```

**To use it:**
```bash
# Make it executable
chmod +x morning-check.sh

# Run it
./morning-check.sh

# Or schedule it to run automatically at 9 AM
echo "0 9 * * * $PWD/morning-check.sh" | crontab -
```

---

## SSH Automation Recipes

### 🔐 Recipe 1: Auto-Block Suspicious IPs

**What it does**: Automatically blocks IPs after 3 failed login attempts

```bash
#!/bin/bash
# auto-block-ssh.sh - Automated SSH protection

# Configuration
MAX_ATTEMPTS=3
BAN_TIME=3600  # 1 hour in seconds

# Check for failed attempts
echo "Checking for suspicious SSH activity..."

# Parse auth log for failed attempts
sudo grep "Failed password" /var/log/auth.log | \
    awk '{print $(NF-3)}' | \
    sort | uniq -c | \
    while read count ip; do
        if [ "$count" -ge "$MAX_ATTEMPTS" ]; then
            echo "⚠️  Blocking $ip (failed $count times)"
            
            # Block the IP
            sudo iptables -A INPUT -s "$ip" -j DROP
            
            # Schedule unblock
            echo "sudo iptables -D INPUT -s $ip -j DROP" | \
                at now + $((BAN_TIME/60)) minutes 2>/dev/null
            
            # Send notification
            ./scripts/automation/notify.sh \
                "SSH Security Alert" \
                "Blocked IP $ip after $count failed attempts" \
                "warning"
        fi
    done

echo "✅ SSH protection active"
```

### 🔐 Recipe 2: Secure Remote Backup

**What it does**: Automatically backs up files from multiple servers

```bash
#!/bin/bash
# secure-backup.sh - Automated secure backup system

# Load parallel framework
source scripts/automation/parallel-framework.sh

# Servers to backup
SERVERS=(
    "user@server1.com:/important/data|backups/server1"
    "user@server2.com:/var/www|backups/server2"
    "user@db.com:/var/lib/mysql|backups/database"
)

# Create backup tasks
backup_tasks=()
for server in "${SERVERS[@]}"; do
    IFS='|' read -r source dest <<< "$server"
    
    backup_tasks+=("rsync -avz --delete '$source' '$dest/$(date +%Y%m%d)'")
done

echo "🔄 Starting parallel backup of ${#SERVERS[@]} servers..."

# Run all backups in parallel
parallel_execute backup_tasks 3

# Compress old backups
find backups -type d -name "20*" -mtime +7 -exec tar -czf {}.tar.gz {} \; -exec rm -rf {} \;

echo "✅ Backup complete!"

# Send summary
./scripts/automation/notify.sh \
    "Backup Complete" \
    "Successfully backed up ${#SERVERS[@]} servers" \
    "info"
```

### 🔐 Recipe 3: SSH Key Deployment

**What it does**: Safely deploys SSH keys to multiple servers

```bash
#!/bin/bash
# deploy-ssh-keys.sh - Automated SSH key deployment

# Configuration
KEY_FILE="$HOME/.ssh/id_rsa.pub"
AUTHORIZED_KEYS=".ssh/authorized_keys"

# Server list
cat > servers.txt << EOF
user1@server1.com
user2@server2.com
admin@server3.com
EOF

# Deploy function
deploy_key() {
    local server=$1
    echo "🔑 Deploying key to $server..."
    
    # Create .ssh directory if needed
    ssh "$server" "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
    
    # Copy key
    cat "$KEY_FILE" | ssh "$server" "cat >> ~/$AUTHORIZED_KEYS && chmod 600 ~/$AUTHORIZED_KEYS"
    
    # Test connection
    if ssh -o BatchMode=yes "$server" "echo 'Key deployed successfully'" 2>/dev/null; then
        echo "✅ $server: Success"
    else
        echo "❌ $server: Failed"
    fi
}

# Deploy to all servers
while IFS= read -r server; do
    deploy_key "$server"
done < servers.txt
```

---

## Docker Automation Recipes

### 🐳 Recipe 1: Automated Container Health Monitoring

**What it does**: Monitors containers and restarts unhealthy ones

```bash
#!/bin/bash
# container-health-monitor.sh - Keep containers healthy

# Configuration
CHECK_INTERVAL=60  # seconds
MAX_RESTART_ATTEMPTS=3

# Tracking restart attempts
declare -A restart_counts

while true; do
    echo "🏥 Checking container health..."
    
    # Get all running containers
    docker ps --format "{{.Names}}" | while read container; do
        # Check health status
        health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
        
        case "$health" in
            "unhealthy")
                echo "⚠️  $container is unhealthy"
                
                # Check restart count
                count=${restart_counts[$container]:-0}
                
                if [ "$count" -lt "$MAX_RESTART_ATTEMPTS" ]; then
                    echo "🔄 Restarting $container (attempt $((count+1)))"
                    docker restart "$container"
                    restart_counts[$container]=$((count+1))
                else
                    echo "❌ $container exceeded restart limit"
                    ./scripts/automation/notify.sh \
                        "Container Critical" \
                        "$container failed after $MAX_RESTART_ATTEMPTS restarts" \
                        "critical"
                fi
                ;;
            "healthy")
                # Reset counter on healthy
                restart_counts[$container]=0
                ;;
        esac
    done
    
    sleep "$CHECK_INTERVAL"
done
```

### 🐳 Recipe 2: Automated Image Updates

**What it does**: Updates all Docker images and redeploys containers

```bash
#!/bin/bash
# docker-update-all.sh - Automated Docker updates

# Load parallel framework
source scripts/automation/parallel-framework.sh

echo "🔄 Docker Image Update System"
echo "============================"

# Step 1: Record running containers
echo "📸 Recording current state..."
docker ps --format "{{.Image}}|{{.Names}}|{{.Ports}}" > /tmp/running-containers.txt

# Step 2: Pull latest images (in parallel)
echo "⬇️  Pulling latest images..."
images=($(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>"))

pull_tasks=()
for image in "${images[@]}"; do
    pull_tasks+=("docker pull $image")
done

parallel_execute pull_tasks 5

# Step 3: Scan new images
echo "🔍 Scanning updated images..."
scan_tasks=()
for image in "${images[@]}"; do
    scan_tasks+=("docker-scan $image")
done

parallel_execute scan_tasks 3

# Step 4: Recreate containers with new images
echo "🚀 Recreating containers..."
while IFS='|' read -r image name ports; do
    echo "Updating $name..."
    
    # Stop old container
    docker stop "$name"
    docker rm "$name"
    
    # Start with new image
    port_args=""
    if [ -n "$ports" ]; then
        port_args="-p $ports"
    fi
    
    docker-safe run -d --name "$name" $port_args "$image"
done < /tmp/running-containers.txt

echo "✅ All containers updated!"
```

### 🐳 Recipe 3: Docker Cleanup Automation

**What it does**: Regularly cleans up unused Docker resources

```bash
#!/bin/bash
# docker-cleanup.sh - Automated Docker cleanup

echo "🧹 Docker Cleanup Service"
echo "======================="

# Configuration
KEEP_IMAGES_DAYS=30
KEEP_VOLUMES_DAYS=7

# Function to format bytes
format_bytes() {
    numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || echo "$1 bytes"
}

# Before cleanup
BEFORE_SPACE=$(df / | awk 'NR==2 {print $3}')

echo "📊 Current Docker usage:"
docker system df

echo -e "\n🗑️  Starting cleanup..."

# 1. Remove stopped containers
echo "- Removing stopped containers..."
docker container prune -f

# 2. Remove unused images older than X days
echo "- Removing old unused images..."
docker images --format "{{.Repository}}:{{.Tag}}|{{.ID}}|{{.CreatedAt}}" | \
while IFS='|' read -r name id created; do
    # Check if image is older than threshold
    created_date=$(date -d "$created" +%s 2>/dev/null || echo 0)
    threshold_date=$(date -d "$KEEP_IMAGES_DAYS days ago" +%s)
    
    if [ "$created_date" -lt "$threshold_date" ] && [ "$created_date" -gt 0 ]; then
        echo "  Removing old image: $name"
        docker rmi "$id" 2>/dev/null || true
    fi
done

# 3. Remove unused volumes
echo "- Removing unused volumes..."
docker volume prune -f

# 4. Remove unused networks
echo "- Removing unused networks..."
docker network prune -f

# 5. Remove build cache
echo "- Removing build cache..."
docker builder prune -f

# After cleanup
AFTER_SPACE=$(df / | awk 'NR==2 {print $3}')
FREED=$((BEFORE_SPACE - AFTER_SPACE))

echo -e "\n✅ Cleanup complete!"
echo "💾 Space freed: $(format_bytes $((FREED * 1024)))"

# Show new usage
docker system df
```

---

## Parallel Processing Recipes

### ⚡ Recipe 1: Multi-Server Security Audit

**What it does**: Audits multiple servers simultaneously

```bash
#!/bin/bash
# parallel-security-audit.sh - Fast multi-server auditing

source scripts/automation/parallel-framework.sh

# Server list
SERVERS=(
    "web1.company.com"
    "web2.company.com"
    "db1.company.com"
    "app1.company.com"
)

# Audit function
audit_server() {
    local server=$1
    local report_dir="audits/$(date +%Y%m%d)/$server"
    mkdir -p "$report_dir"
    
    echo "🔍 Auditing $server..."
    
    # Run multiple checks
    nmap -sV "$server" > "$report_dir/nmap.txt" 2>&1
    ssh "$server" "sudo lynis audit system --quick" > "$report_dir/lynis.txt" 2>&1
    testssl.sh "$server:443" > "$report_dir/ssl.txt" 2>&1
    
    # Generate summary
    echo "Server: $server" > "$report_dir/summary.txt"
    echo "Date: $(date)" >> "$report_dir/summary.txt"
    echo "Open Ports: $(grep -c "open" "$report_dir/nmap.txt")" >> "$report_dir/summary.txt"
    echo "SSL Grade: $(grep "Rating" "$report_dir/ssl.txt" | head -1)" >> "$report_dir/summary.txt"
    
    echo "✅ $server audit complete"
}

# Create audit tasks
audit_tasks=()
for server in "${SERVERS[@]}"; do
    audit_tasks+=("audit_server $server")
done

echo "🚀 Starting parallel audit of ${#SERVERS[@]} servers..."
START_TIME=$(date +%s)

# Run audits in parallel
parallel_execute audit_tasks 4

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "⏱️  Total time: ${DURATION} seconds"
echo "📊 Reports saved in: audits/$(date +%Y%m%d)/"

# Generate combined report
cat audits/$(date +%Y%m%d)/*/summary.txt > audits/$(date +%Y%m%d)/all-servers-summary.txt
```

### ⚡ Recipe 2: Bulk Security Updates

**What it does**: Updates security tools across multiple systems

```bash
#!/bin/bash
# parallel-security-updates.sh - Update everything at once

source scripts/automation/parallel-framework.sh

echo "🔄 Security Tools Mass Update"
echo "==========================="

# Define update tasks
update_tasks=(
    # System packages
    "sudo apt update && sudo apt upgrade -y"
    
    # Docker images
    "docker pull aquasec/trivy:latest"
    "docker pull prom/prometheus:latest"
    "docker pull grafana/grafana:latest"
    
    # Git repositories
    "cd /opt/tools/nuclei && git pull"
    "cd /opt/tools/nmap-scripts && git pull"
    "cd /opt/docs/owasp-cheatsheet && git pull"
    
    # Python tools
    "pip3 install --upgrade sqlmap"
    "pip3 install --upgrade ansible"
    
    # Golang tools
    "go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest"
    "go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest"
)

echo "📋 Updating ${#update_tasks[@]} components..."

# Run all updates in parallel
parallel_execute update_tasks 5

echo "✅ All security tools updated!"

# Verify versions
echo -e "\n📊 Current versions:"
echo "Docker: $(docker --version)"
echo "Trivy: $(docker run --rm aquasec/trivy --version)"
echo "Nuclei: $(nuclei -version 2>/dev/null | head -1)"
```

---

## Security Scanning Automation

### 🔍 Recipe 1: Scheduled Vulnerability Scanning

**What it does**: Runs comprehensive scans on a schedule

```bash
#!/bin/bash
# scheduled-security-scan.sh - Automated vulnerability scanning

# Configuration
SCAN_TARGETS_FILE="scan-targets.txt"
SCAN_RESULTS_DIR="scan-results/$(date +%Y%m%d-%H%M%S)"
CRITICAL_THRESHOLD=5

# Create results directory
mkdir -p "$SCAN_RESULTS_DIR"

echo "🔍 Automated Security Scan Starting"
echo "=================================="
echo "Time: $(date)"
echo "Results: $SCAN_RESULTS_DIR"

# Function to scan a target
scan_target() {
    local target=$1
    local target_dir="$SCAN_RESULTS_DIR/${target//\//_}"
    mkdir -p "$target_dir"
    
    echo "📡 Scanning $target..."
    
    # Network scan
    nmap -sV -sC "$target" -oA "$target_dir/nmap" &
    
    # Web vulnerability scan
    if [[ "$target" =~ ^https?:// ]]; then
        nikto -h "$target" -o "$target_dir/nikto.txt" &
        nuclei -u "$target" -o "$target_dir/nuclei.txt" &
    fi
    
    # Wait for scans to complete
    wait
    
    # Count vulnerabilities
    local vulns=$(grep -c "vulnerability\|critical" "$target_dir"/*.txt 2>/dev/null || echo 0)
    echo "$target: $vulns vulnerabilities found" >> "$SCAN_RESULTS_DIR/summary.txt"
    
    # Alert on critical findings
    if [ "$vulns" -ge "$CRITICAL_THRESHOLD" ]; then
        ./scripts/automation/notify.sh \
            "Critical Security Finding" \
            "$vulns vulnerabilities found on $target" \
            "critical"
    fi
}

# Load targets
if [ ! -f "$SCAN_TARGETS_FILE" ]; then
    # Create example targets file
    cat > "$SCAN_TARGETS_FILE" << EOF
192.168.1.1
https://example.com
10.0.0.0/24
EOF
fi

# Scan all targets
while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    scan_target "$target" &
done < "$SCAN_TARGETS_FILE"

# Wait for all scans
wait

# Generate report
echo -e "\n📊 Scan Summary"
echo "==============="
cat "$SCAN_RESULTS_DIR/summary.txt"

# Schedule next scan (if running as cron job)
echo -e "\n⏰ Next scan scheduled for tomorrow at 2 AM"
```

### 🔍 Recipe 2: Container Security Pipeline

**What it does**: Scans containers before deployment

```bash
#!/bin/bash
# container-security-pipeline.sh - Secure container deployment

# Configuration
SEVERITY_THRESHOLD="HIGH,CRITICAL"
BLOCK_ON_VULNERABILITIES=true

echo "🛡️  Container Security Pipeline"
echo "============================"

# Function to scan and deploy
secure_deploy() {
    local image=$1
    local container_name=$2
    local run_args=$3
    
    echo "🔍 Scanning $image..."
    
    # Create temporary results file
    SCAN_RESULT="/tmp/scan-${container_name}-$(date +%s).json"
    
    # Scan image
    docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        aquasec/trivy image \
        --format json \
        --severity "$SEVERITY_THRESHOLD" \
        --output "$SCAN_RESULT" \
        "$image"
    
    # Check for vulnerabilities
    VULN_COUNT=$(jq '[.Results[].Vulnerabilities | length] | add' "$SCAN_RESULT" 2>/dev/null || echo 0)
    
    if [ "$VULN_COUNT" -gt 0 ]; then
        echo "⚠️  Found $VULN_COUNT vulnerabilities!"
        
        # Show critical vulnerabilities
        jq -r '.Results[].Vulnerabilities[] | select(.Severity == "CRITICAL") | "  - \(.VulnerabilityID): \(.Title)"' "$SCAN_RESULT" 2>/dev/null
        
        if [ "$BLOCK_ON_VULNERABILITIES" = true ]; then
            echo "❌ Deployment blocked due to vulnerabilities"
            
            # Save report
            cp "$SCAN_RESULT" "blocked-deployments/"
            
            # Notify security team
            ./scripts/automation/notify.sh \
                "Deployment Blocked" \
                "Container $container_name blocked: $VULN_COUNT vulnerabilities" \
                "critical"
            
            return 1
        else
            echo "⚠️  Proceeding with deployment (vulnerabilities noted)"
        fi
    else
        echo "✅ No vulnerabilities found"
    fi
    
    # Deploy container
    echo "🚀 Deploying $container_name..."
    eval "docker-safe run -d --name $container_name $run_args $image"
    
    # Verify deployment
    if docker ps | grep -q "$container_name"; then
        echo "✅ $container_name deployed successfully"
    else
        echo "❌ $container_name deployment failed"
        return 1
    fi
    
    # Cleanup
    rm -f "$SCAN_RESULT"
}

# Example deployments
secure_deploy "nginx:latest" "web-server" "-p 80:80"
secure_deploy "mysql:8" "database" "-p 3306:3306 -e MYSQL_ROOT_PASSWORD=secure123"
secure_deploy "redis:alpine" "cache" "-p 6379:6379"
```

---

## Monitoring and Alerting

### 📊 Recipe 1: Smart Alert Aggregation

**What it does**: Combines multiple alerts into meaningful notifications

```bash
#!/bin/bash
# smart-alert-system.sh - Intelligent alert management

# Configuration
ALERT_WINDOW=300  # 5 minutes
ALERT_THRESHOLD=5  # Alerts before escalation

# Alert storage
ALERT_DB="/var/log/security/alert-db"
mkdir -p "$ALERT_DB"

# Function to process alerts
process_alert() {
    local alert_type=$1
    local alert_message=$2
    local severity=$3
    
    # Create alert ID
    ALERT_ID="${alert_type}_$(date +%s)"
    
    # Check for similar recent alerts
    SIMILAR_COUNT=$(find "$ALERT_DB" -name "${alert_type}_*" -mmin -5 | wc -l)
    
    if [ "$SIMILAR_COUNT" -ge "$ALERT_THRESHOLD" ]; then
        # Escalate repeated alerts
        echo "🚨 ESCALATION: $alert_type occurring frequently ($SIMILAR_COUNT times)"
        
        # Send high-priority notification
        ./scripts/automation/notify.sh \
            "Security Escalation" \
            "$alert_type: $SIMILAR_COUNT occurrences in 5 minutes" \
            "critical"
        
        # Clear old alerts to prevent spam
        find "$ALERT_DB" -name "${alert_type}_*" -delete
    else
        # Store alert
        echo "$alert_message" > "$ALERT_DB/$ALERT_ID"
        
        # Send normal notification
        if [ "$severity" = "critical" ] || [ "$SIMILAR_COUNT" -eq 0 ]; then
            ./scripts/automation/notify.sh \
                "Security Alert" \
                "$alert_message" \
                "$severity"
        fi
    fi
    
    # Cleanup old alerts
    find "$ALERT_DB" -type f -mmin +60 -delete
}

# Monitor multiple sources
monitor_sources() {
    # SSH failures
    tail -F /var/log/auth.log | while read line; do
        if echo "$line" | grep -q "Failed password"; then
            IP=$(echo "$line" | grep -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}")
            process_alert "ssh_failure" "Failed SSH login from $IP" "warning"
        fi
    done &
    
    # Docker events
    docker events --format '{{json .}}' | while read event; do
        if echo "$event" | jq -r .status | grep -q "die"; then
            CONTAINER=$(echo "$event" | jq -r .Actor.Attributes.name)
            process_alert "container_died" "Container $CONTAINER stopped unexpectedly" "warning"
        fi
    done &
    
    # File changes
    inotifywait -m -r /etc --format '%w%f %e' | while read file event; do
        if [[ "$event" =~ MODIFY|CREATE|DELETE ]]; then
            process_alert "config_change" "Configuration file changed: $file" "info"
        fi
    done &
    
    wait
}

echo "🛡️  Smart Alert System Active"
echo "Monitoring SSH, Docker, and Configuration changes..."
monitor_sources
```

### 📊 Recipe 2: Performance-Aware Monitoring

**What it does**: Adjusts monitoring based on system load

```bash
#!/bin/bash
# adaptive-monitoring.sh - Smart resource-aware monitoring

# Configuration
HIGH_LOAD_THRESHOLD=80
LOW_LOAD_THRESHOLD=30

# Monitoring levels
FULL_MONITORING_INTERVAL=60
REDUCED_MONITORING_INTERVAL=300
MINIMAL_MONITORING_INTERVAL=900

get_system_load() {
    # Get CPU usage percentage
    top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}'
}

adaptive_monitor() {
    while true; do
        LOAD=$(get_system_load | cut -d. -f1)
        
        echo "📊 System load: ${LOAD}%"
        
        if [ "$LOAD" -gt "$HIGH_LOAD_THRESHOLD" ]; then
            echo "🔴 High load detected - reducing monitoring"
            INTERVAL=$MINIMAL_MONITORING_INTERVAL
            
            # Run only critical checks
            security-status | grep -E "CRITICAL|FAIL" || true
            
        elif [ "$LOAD" -lt "$LOW_LOAD_THRESHOLD" ]; then
            echo "🟢 Low load - full monitoring active"
            INTERVAL=$FULL_MONITORING_INTERVAL
            
            # Run all checks
            security-status
            docker ps --format "table {{.Names}}\t{{.Status}}"
            ssh_login_history 5
            
        else
            echo "🟡 Normal load - standard monitoring"
            INTERVAL=$REDUCED_MONITORING_INTERVAL
            
            # Run standard checks
            security-status | grep -v "INFO" || true
        fi
        
        sleep "$INTERVAL"
    done
}

echo "🤖 Adaptive Monitoring System"
echo "=========================="
echo "Will adjust monitoring intensity based on system load"
adaptive_monitor
```

---

## Custom Workflows

### 🎯 Recipe 1: Complete Security Workflow

**What it does**: A full security workflow from scan to report

```bash
#!/bin/bash
# complete-security-workflow.sh - End-to-end security automation

# Configuration
PROJECT_NAME="SecurityAudit_$(date +%Y%m%d)"
REPORT_DIR="reports/$PROJECT_NAME"

# Load frameworks
source scripts/automation/parallel-framework.sh

echo "🚀 Complete Security Workflow: $PROJECT_NAME"
echo "========================================"

# Step 1: Environment Preparation
echo -e "\n📋 Step 1: Preparing environment..."
mkdir -p "$REPORT_DIR"/{scans,logs,evidence,summary}

# Step 2: Asset Discovery
echo -e "\n🔍 Step 2: Asset discovery..."
cat > "$REPORT_DIR/assets.txt" << EOF
192.168.1.0/24
web.example.com
api.example.com
EOF

# Discover live hosts
nmap -sn -iL "$REPORT_DIR/assets.txt" -oG - | \
    grep "Up" | cut -d' ' -f2 > "$REPORT_DIR/live-hosts.txt"

# Step 3: Parallel Security Scanning
echo -e "\n🔍 Step 3: Security scanning..."
scan_tasks=()
while IFS= read -r host; do
    scan_tasks+=(
        "nmap -sV -sC $host -oA $REPORT_DIR/scans/nmap-$host"
        "nikto -h $host -o $REPORT_DIR/scans/nikto-$host.txt"
    )
done < "$REPORT_DIR/live-hosts.txt"

parallel_execute scan_tasks 5

# Step 4: Vulnerability Analysis
echo -e "\n📊 Step 4: Analyzing vulnerabilities..."
find "$REPORT_DIR/scans" -name "*.txt" -o -name "*.xml" | \
while read scan_file; do
    grep -iE "vulnerab|critical|high|exploit" "$scan_file" >> "$REPORT_DIR/summary/vulnerabilities.txt" 2>/dev/null || true
done

# Step 5: Container Security
echo -e "\n🐳 Step 5: Container security check..."
docker images --format "{{.Repository}}:{{.Tag}}" | \
while read image; do
    echo "Scanning $image..."
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
        aquasec/trivy image "$image" >> "$REPORT_DIR/summary/container-vulns.txt" 2>&1
done

# Step 6: Generate Executive Report
echo -e "\n📄 Step 6: Generating report..."
cat > "$REPORT_DIR/Executive_Summary.md" << EOF
# Security Assessment Report
**Date**: $(date)
**Project**: $PROJECT_NAME

## Executive Summary

### Assets Scanned
- Total Networks: $(wc -l < "$REPORT_DIR/assets.txt")
- Live Hosts: $(wc -l < "$REPORT_DIR/live-hosts.txt")
- Container Images: $(docker images -q | wc -l)

### Key Findings
$(grep -c "CRITICAL" "$REPORT_DIR/summary/vulnerabilities.txt" 2>/dev/null || echo 0) Critical vulnerabilities
$(grep -c "HIGH" "$REPORT_DIR/summary/vulnerabilities.txt" 2>/dev/null || echo 0) High severity issues
$(grep -c "MEDIUM" "$REPORT_DIR/summary/vulnerabilities.txt" 2>/dev/null || echo 0) Medium severity issues

### Immediate Actions Required
1. Review critical vulnerabilities in: $REPORT_DIR/summary/vulnerabilities.txt
2. Update vulnerable containers listed in: $REPORT_DIR/summary/container-vulns.txt
3. Implement recommended security controls

### Next Steps
- Schedule follow-up scan in 30 days
- Implement remediation plan
- Update security policies
EOF

# Step 7: Notification
echo -e "\n📧 Step 7: Sending notifications..."
./scripts/automation/notify.sh \
    "Security Workflow Complete" \
    "Report available at: $REPORT_DIR/Executive_Summary.md" \
    "info"

echo -e "\n✅ Workflow complete!"
echo "📊 Full report: $REPORT_DIR/Executive_Summary.md"

# Open report
if command -v xdg-open &> /dev/null; then
    xdg-open "$REPORT_DIR/Executive_Summary.md"
fi
```

### 🎯 Recipe 2: Incident Response Workflow

**What it does**: Automated incident response with evidence collection

```bash
#!/bin/bash
# incident-response-workflow.sh - Automated IR process

# Configuration
INCIDENT_ID="INC$(date +%Y%m%d%H%M%S)"
IR_DIR="incidents/$INCIDENT_ID"

echo "🚨 Incident Response Workflow"
echo "==========================="
echo "Incident ID: $INCIDENT_ID"

# Create IR structure
mkdir -p "$IR_DIR"/{evidence,logs,timeline,reports}

# Step 1: Isolate
echo -e "\n🔒 Step 1: Isolation..."
read -p "Isolate affected system? (y/n): " isolate
if [[ "$isolate" == "y" ]]; then
    # Add firewall rules to isolate
    sudo iptables -I INPUT -s 0.0.0.0/0 -j DROP
    sudo iptables -I OUTPUT -d 0.0.0.0/0 -j DROP
    # Allow only IR team access
    sudo iptables -I INPUT -s 10.0.0.100 -j ACCEPT
    echo "✅ System isolated"
fi

# Step 2: Evidence Collection
echo -e "\n📸 Step 2: Collecting evidence..."
ir-snapshot  # Use our IR snapshot function
mv /tmp/ir-snapshot-*.tar.gz "$IR_DIR/evidence/"

# Collect additional evidence
ps auxf > "$IR_DIR/evidence/processes.txt"
netstat -tulpn > "$IR_DIR/evidence/network.txt" 2>&1
last -100 > "$IR_DIR/evidence/logins.txt"

# Step 3: Timeline Creation
echo -e "\n⏱️  Step 3: Creating timeline..."
{
    echo "Incident Timeline for $INCIDENT_ID"
    echo "================================"
    echo
    # System logs
    sudo journalctl --since "6 hours ago" | grep -E "error|fail|critical|warning" | head -100
    echo
    # Auth logs
    sudo tail -1000 /var/log/auth.log | grep -E "Failed|Accepted|sudo"
} > "$IR_DIR/timeline/events.txt"

# Step 4: Analysis
echo -e "\n🔍 Step 4: Analyzing..."
# Check for suspicious processes
ps aux | grep -vE "^\[|kernel|systemd" | awk '{if($3>50.0) print "High CPU: " $0}' > "$IR_DIR/reports/suspicious.txt"

# Check for unusual network connections
netstat -an | grep ESTABLISHED | grep -vE "127.0.0.1|::1" >> "$IR_DIR/reports/suspicious.txt"

# Step 5: Containment Actions
echo -e "\n🛡️  Step 5: Containment..."
read -p "Kill suspicious processes? (y/n): " kill_procs
if [[ "$kill_procs" == "y" ]]; then
    # Example: Kill high CPU processes
    ps aux | awk '{if($3>80.0) print $2}' | xargs -r kill -9
fi

# Step 6: Generate Report
cat > "$IR_DIR/Incident_Report.md" << EOF
# Incident Report: $INCIDENT_ID

## Incident Details
- **Date/Time**: $(date)
- **Type**: [Classification needed]
- **Severity**: [High/Medium/Low]
- **Status**: In Progress

## Timeline
See: timeline/events.txt

## Evidence Collected
- Process snapshot: evidence/processes.txt
- Network connections: evidence/network.txt
- Login history: evidence/logins.txt
- Full system snapshot: evidence/ir-snapshot-*.tar.gz

## Actions Taken
- System isolated: $isolate
- Processes terminated: $kill_procs
- Evidence preserved

## Next Steps
1. Complete forensic analysis
2. Identify root cause
3. Implement remediation
4. Update security controls

## Lessons Learned
[To be completed post-incident]
EOF

echo -e "\n✅ Incident response complete!"
echo "📁 All data saved in: $IR_DIR"
echo "📊 Report: $IR_DIR/Incident_Report.md"

# Notify team
./scripts/automation/notify.sh \
    "Incident Response Complete" \
    "IR $INCIDENT_ID complete. Report at: $IR_DIR" \
    "critical"
```

---

## Tips for Success 🌟

### For Beginners
1. **Start Small**: Use one recipe at a time
2. **Test First**: Always test in a safe environment
3. **Read Output**: Understand what each command does
4. **Ask Questions**: Use `help-security` when stuck

### For Advanced Users
1. **Customize**: Modify recipes for your environment
2. **Combine**: Chain recipes together
3. **Scale**: Use parallel execution for large environments
4. **Integrate**: Connect with your existing tools

### Universal Tips
- **Log Everything**: Automation should create logs
- **Error Handling**: Always plan for failures
- **Notifications**: Know when things happen
- **Documentation**: Comment your custom scripts

---

## Quick Recipe Reference

| Task | Recipe | Time Saved |
|------|---------|------------|
| Morning security check | `morning-check.sh` | 10 min/day |
| SSH protection | `auto-block-ssh.sh` | 30 min/incident |
| Multi-server backup | `secure-backup.sh` | 2 hours/week |
| Container health | `container-health-monitor.sh` | 1 hour/day |
| Security updates | `parallel-security-updates.sh` | 3 hours/month |
| Full security scan | `scheduled-security-scan.sh` | 4 hours/week |
| Incident response | `incident-response-workflow.sh` | 2 hours/incident |

Remember: These recipes are starting points. Customize them to fit your needs and make them your own! 🚀