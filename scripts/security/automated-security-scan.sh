#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
# Automated security scanning with parallel execution

source "$(dirname "$0")/../automation/parallel-framework.sh"

SCAN_DATE=$(date +%Y%m%d_%H%M%S)
SCAN_DIR="scans/$SCAN_DATE"
mkdir -p "$SCAN_DIR"

echo "Starting automated security scan..."

# Container scanning tasks
container_tasks=()
for image in $(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>"); do
    container_tasks+=("docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --format json --output $SCAN_DIR/${image//\//_}.json $image")
done

# Network scanning tasks
network_tasks=()
for target in $(cat targets.txt 2>/dev/null || echo "localhost"); do
    network_tasks+=("nmap -sV -sC -oA $SCAN_DIR/nmap_${target} $target")
done

# File system scanning
fs_tasks=(
    "lynis audit system --quick --report-file $SCAN_DIR/lynis.dat"
    "chkrootkit > $SCAN_DIR/chkrootkit.log 2>&1"
    "find / -type f -perm -4000 2>/dev/null > $SCAN_DIR/suid_files.txt"
)

# Execute all scans in parallel
echo "Scanning containers..."
parallel_execute container_tasks 5

echo "Scanning network..."
parallel_execute network_tasks 3

echo "Scanning file system..."
parallel_execute fs_tasks 2

# Generate summary report
cat > "$SCAN_DIR/summary.txt" << EOL
Security Scan Summary
====================
Date: $(date)
Container Images Scanned: ${#container_tasks[@]}
Network Targets Scanned: ${#network_tasks[@]}
File System Checks: ${#fs_tasks[@]}

Results Location: $SCAN_DIR
EOL

echo "Security scan complete! Results in: $SCAN_DIR"
