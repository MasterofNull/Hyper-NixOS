#!/bin/bash
# Advanced Security Functions and Techniques
# Implements high-value tips and tricks for security operations

# Color codes
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

echo -e "${BLUE}Loading advanced security functions...${NC}"

# ============================================
# SSH AND REMOTE ACCESS
# ============================================

# SSH with automatic filesystem mount
sshm() {
    local TARGET_HOST TARGET_USER TARGET_DIR
    
    # Parse SSH command format
    TARGET_HOST=$(echo "$@" | grep -oE '[^@]+$' | cut -d' ' -f1)
    if [[ "$@" == *"@"* ]]; then
        TARGET_USER=$(echo "$@" | grep -oE '^[^@]+')
    else
        TARGET_USER="$USER"
    fi
    
    # Create mount directory
    TARGET_DIR="$HOME/mnt/${TARGET_HOST}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$TARGET_DIR"
    
    echo -e "${YELLOW}Mounting ${TARGET_USER}@${TARGET_HOST} to ${TARGET_DIR}${NC}"
    
    # Mount and connect
    if sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 \
        "${TARGET_USER}@${TARGET_HOST}:/" "$TARGET_DIR" 2>/dev/null; then
        
        echo -e "${GREEN}Filesystem mounted. Connecting...${NC}"
        ssh "$@"
        
        # Cleanup on exit
        echo -e "${YELLOW}Unmounting filesystem...${NC}"
        fusermount -u "$TARGET_DIR" 2>/dev/null
        rmdir "$TARGET_DIR" 2>/dev/null
    else
        echo -e "${RED}Failed to mount filesystem. Connecting without mount...${NC}"
        ssh "$@"
    fi
}

# SSH login monitoring
setup_ssh_monitoring() {
    # Add to .bashrc/.zshrc
    cat >> ~/.bashrc << 'EOF'
# SSH Login Monitoring
if [[ -n "$SSH_CONNECTION" ]]; then
    # Log SSH access
    echo "[$(date)] SSH Login from $SSH_CLIENT" >> ~/.ssh_access.log
    
    # Send notification if notification command exists
    if command -v notify-send &> /dev/null; then
        notify-send "SSH Login Alert" "Connection from $SSH_CLIENT" -u critical
    fi
fi
EOF
    echo -e "${GREEN}SSH monitoring configured${NC}"
}

# ============================================
# DOCKER SECURITY PATTERNS
# ============================================

# Secure docker run with directory check
docker-safe-run() {
    # Security check - prevent running in sensitive directories
    local FORBIDDEN_DIRS=("$HOME" "/" "/etc" "/root" "$HOME/.ssh" "$HOME/.aws")
    local CURRENT_DIR=$(pwd)
    
    for dir in "${FORBIDDEN_DIRS[@]}"; do
        if [[ "$CURRENT_DIR" == "$dir" ]]; then
            echo -e "${RED}ERROR: Cannot run Docker with volume mount in $dir${NC}"
            echo "This is a security measure to prevent exposing sensitive files."
            return 1
        fi
    done
    
    # Run docker command
    docker run --rm -v "$(pwd):/workspace" "$@"
}

# Docker volume caching pattern
docker-with-cache() {
    local VOLUME_NAME=$1
    local GENERATE_CMD=$2
    local SERVE_CMD=$3
    
    if docker volume inspect "$VOLUME_NAME" &>/dev/null; then
        echo -e "${YELLOW}Volume $VOLUME_NAME exists.${NC}"
        read -p "Use existing data? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            eval "$SERVE_CMD"
            return
        fi
    fi
    
    echo -e "${YELLOW}Generating new data...${NC}"
    eval "$GENERATE_CMD"
    eval "$SERVE_CMD"
}

# Clean docker containers by pattern
docker-clean() {
    local PATTERN=$1
    if [[ -z "$PATTERN" ]]; then
        echo "Usage: docker-clean <name-pattern>"
        return 1
    fi
    
    local CONTAINERS=$(docker ps -a -q -f "name=$PATTERN")
    if [[ -n "$CONTAINERS" ]]; then
        echo -e "${YELLOW}Stopping and removing containers matching '$PATTERN'${NC}"
        docker stop $CONTAINERS
        docker rm $CONTAINERS
        echo -e "${GREEN}Cleaned up containers${NC}"
    else
        echo "No containers found matching '$PATTERN'"
    fi
}

# ============================================
# NETWORK SECURITY UTILITIES
# ============================================

# Expose local service via localhost.run
expose-service() {
    local PORT=$1
    local SERVICE_NAME=${2:-"service"}
    
    if [[ -z "$PORT" ]]; then
        echo "Usage: expose-service <port> [service-name]"
        return 1
    fi
    
    echo -e "${YELLOW}Exposing $SERVICE_NAME on port $PORT via localhost.run${NC}"
    echo -e "${BLUE}Press Ctrl+C to stop${NC}"
    
    ssh -R 80:localhost:$PORT nokey@localhost.run
}

# Quick SMB server in current directory
smb-serve() {
    if [[ "$(pwd)" == "$HOME" ]]; then
        echo -e "${RED}ERROR: Cannot share home directory${NC}"
        return 1
    fi
    
    local SHARE_NAME=${1:-"share"}
    local PASSWORD=$(openssl rand -base64 12)
    
    echo -e "${YELLOW}Starting SMB server...${NC}"
    echo -e "${BLUE}Share: //${SHARE_NAME}${NC}"
    echo -e "${BLUE}Username: user${NC}"
    echo -e "${BLUE}Password: $PASSWORD${NC}"
    
    docker run --rm -it -p 445:445 -v "$(pwd):/share" dperson/samba \
        -s "$SHARE_NAME;/share;yes;no;no;user;user" \
        -u "user;$PASSWORD"
}

# Deploy Tor SOCKS proxies
tor-array() {
    local COUNT=${1:-3}
    local BASE_PORT=${2:-9050}
    
    echo -e "${YELLOW}Deploying $COUNT Tor instances...${NC}"
    
    for i in $(seq 1 $COUNT); do
        local PORT=$((BASE_PORT + i - 1))
        docker run -d --name "tor-proxy-$i" \
            -p "127.0.0.1:$PORT:9050" \
            dperson/torproxy
        echo -e "${GREEN}Tor proxy $i running on port $PORT${NC}"
    done
    
    echo -e "\n${BLUE}To use with curl:${NC}"
    echo "curl --socks5 localhost:$BASE_PORT https://check.torproject.org"
}

# ============================================
# AUTOMATION HELPERS
# ============================================

# Smart git update with cache
git-smart-update() {
    local REPO_URL=$1
    local TARGET_DIR=$2
    local FORCE=${3:-0}
    
    # Check if recently updated (within 24 hours)
    if [[ -d "$TARGET_DIR/.git" ]] && [[ $FORCE -eq 0 ]]; then
        local LAST_FETCH=$(stat -c %Y "$TARGET_DIR/.git/FETCH_HEAD" 2>/dev/null || echo 0)
        local CURRENT_TIME=$(date +%s)
        local TIME_DIFF=$((CURRENT_TIME - LAST_FETCH))
        
        if [[ $TIME_DIFF -lt 86400 ]]; then
            echo -e "${BLUE}Repository updated within 24 hours, skipping...${NC}"
            return 0
        fi
    fi
    
    # Clone or update
    if [[ ! -d "$TARGET_DIR" ]]; then
        echo -e "${YELLOW}Cloning $REPO_URL...${NC}"
        git clone --depth 1 "$REPO_URL" "$TARGET_DIR"
    else
        echo -e "${YELLOW}Updating $TARGET_DIR...${NC}"
        cd "$TARGET_DIR"
        git fetch --depth 1
        git reset --hard origin/$(git symbolic-ref --short HEAD)
        cd - > /dev/null
    fi
}

# Background task with notification
run-with-notify() {
    local TASK_NAME=$1
    shift
    local COMMAND="$@"
    
    local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local LOG_FILE="/tmp/${TASK_NAME}_${TIMESTAMP}.log"
    
    echo -e "${YELLOW}Starting $TASK_NAME in background...${NC}"
    echo -e "${BLUE}Log: $LOG_FILE${NC}"
    
    # Run in background
    (
        $COMMAND > "$LOG_FILE" 2>&1
        EXIT_CODE=$?
        
        if [[ $EXIT_CODE -eq 0 ]]; then
            notify-send "Task Complete" "$TASK_NAME finished successfully" -i dialog-information
        else
            notify-send "Task Failed" "$TASK_NAME failed with exit code $EXIT_CODE" -u critical -i dialog-error
        fi
    ) &
    
    local PID=$!
    echo -e "${GREEN}Task running with PID $PID${NC}"
}

# ============================================
# SECURITY TESTING UTILITIES
# ============================================

# Content length detection for web fuzzing
detect-404-size() {
    local TARGET=$1
    
    if [[ -z "$TARGET" ]]; then
        echo "Usage: detect-404-size <target-url>"
        return 1
    fi
    
    echo -e "${YELLOW}Detecting 404 page size for $TARGET${NC}"
    
    # Generate random paths
    local UUID1=$(uuidgen)
    local UUID2=$(uuidgen)
    
    echo -e "\n${BLUE}Testing random paths:${NC}"
    local SIZE1=$(curl -sI "$TARGET/404test$UUID1" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
    local SIZE2=$(curl -sI "$TARGET/test404$UUID2" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
    
    echo "Path 1: $SIZE1 bytes"
    echo "Path 2: $SIZE2 bytes"
    
    if [[ "$SIZE1" == "$SIZE2" ]]; then
        echo -e "\n${GREEN}404 page size: $SIZE1 bytes${NC}"
        echo "Use this with gobuster: --exclude-length $SIZE1"
    else
        echo -e "\n${YELLOW}WARNING: Inconsistent 404 sizes detected${NC}"
    fi
}

# Parallel scanning orchestrator
parallel-scan() {
    local TARGET=$1
    local SCAN_DIR="$HOME/scans/$(date +%Y%m%d_%H%M%S)_$(echo $TARGET | sed 's|[/:.]|_|g')"
    
    mkdir -p "$SCAN_DIR"
    echo -e "${YELLOW}Scan directory: $SCAN_DIR${NC}"
    
    # Run scans in parallel
    echo -e "${BLUE}Starting parallel scans...${NC}"
    
    # Nmap scan
    nmap -sV -sC -oA "$SCAN_DIR/nmap" "$TARGET" &
    local NMAP_PID=$!
    
    # Nikto scan
    nikto -h "$TARGET" -o "$SCAN_DIR/nikto.txt" &
    local NIKTO_PID=$!
    
    # Directory enumeration
    gobuster dir -u "$TARGET" -w /usr/share/wordlists/dirb/common.txt \
        -o "$SCAN_DIR/gobuster.txt" &
    local GOBUSTER_PID=$!
    
    # Wait for all scans
    echo -e "${YELLOW}Waiting for scans to complete...${NC}"
    wait $NMAP_PID $NIKTO_PID $GOBUSTER_PID
    
    echo -e "${GREEN}All scans completed!${NC}"
    echo -e "${BLUE}Results in: $SCAN_DIR${NC}"
}

# ============================================
# TEMPORARY FILE MANAGEMENT
# ============================================

# Create secure temporary file
secure-temp() {
    local PREFIX=${1:-"security"}
    local TEMP_FILE="/tmp/${PREFIX}_$(uuidgen | cut -d'-' -f1)_$(date +%s)"
    
    # Create with restricted permissions
    touch "$TEMP_FILE"
    chmod 600 "$TEMP_FILE"
    
    echo "$TEMP_FILE"
}

# Cleanup old temporary files
cleanup-temp() {
    local DAYS=${1:-7}
    echo -e "${YELLOW}Cleaning temporary files older than $DAYS days...${NC}"
    
    find /tmp -name "security_*" -type f -mtime +$DAYS -delete
    find /tmp -name "scan_*" -type f -mtime +$DAYS -delete
    
    echo -e "${GREEN}Cleanup completed${NC}"
}

# ============================================
# NOTIFICATION SYSTEM
# ============================================

# Desktop notification with action
notify-action() {
    local TITLE=$1
    local MESSAGE=$2
    local ACTION_URL=$3
    
    if command -v dunstify &> /dev/null; then
        ACTION=$(dunstify --action="default,Open" "$TITLE" "$MESSAGE")
        if [[ "$ACTION" == "default" ]] && [[ -n "$ACTION_URL" ]]; then
            xdg-open "$ACTION_URL"
        fi
    elif command -v notify-send &> /dev/null; then
        notify-send "$TITLE" "$MESSAGE"
    else
        echo "[$TITLE] $MESSAGE"
    fi
}

# ============================================
# PASSWORD AND SECRET MANAGEMENT
# ============================================

# Generate password with QR code
pass-gen-qr() {
    local LENGTH=${1:-16}
    local PASSWORD=$(openssl rand -base64 48 | tr -d "=+/" | cut -c1-$LENGTH)
    
    echo -e "${BLUE}Generated Password:${NC} $PASSWORD"
    
    if command -v qrencode &> /dev/null; then
        echo -e "\n${YELLOW}QR Code:${NC}"
        echo -n "$PASSWORD" | qrencode -t UTF8
    fi
    
    # Copy to clipboard if xclip available
    if command -v xclip &> /dev/null; then
        echo -n "$PASSWORD" | xclip -selection clipboard
        echo -e "\n${GREEN}Password copied to clipboard${NC}"
    fi
}

# ============================================
# QUICK DEPLOYMENT FUNCTIONS
# ============================================

# Deploy web server with upload capability
deploy-upload-server() {
    local PORT=${1:-8080}
    
    echo -e "${YELLOW}Deploying upload server on port $PORT${NC}"
    echo -e "${RED}WARNING: This allows file uploads. Use with caution!${NC}"
    
    # Create upload directory
    mkdir -p ./uploads
    
    # Python simple upload server
    cat > /tmp/upload_server.py << 'EOF'
#!/usr/bin/env python3
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
import cgi

class UploadHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(b'''
        <html><body>
        <h2>File Upload</h2>
        <form method="POST" enctype="multipart/form-data">
        <input type="file" name="file"><br><br>
        <input type="submit" value="Upload">
        </form>
        </body></html>
        ''')
    
    def do_POST(self):
        form = cgi.FieldStorage(
            fp=self.rfile,
            headers=self.headers,
            environ={'REQUEST_METHOD': 'POST'}
        )
        
        file_item = form['file']
        if file_item.filename:
            filename = os.path.basename(file_item.filename)
            with open(f'uploads/{filename}', 'wb') as f:
                f.write(file_item.file.read())
            
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(f'<html><body><h2>Uploaded: {filename}</h2></body></html>'.encode())

if __name__ == '__main__':
    server = HTTPServer(('', PORT), UploadHandler)
    print(f'Server running on port {PORT}')
    server.serve_forever()
EOF
    
    sed -i "s/PORT/$PORT/g" /tmp/upload_server.py
    python3 /tmp/upload_server.py
}

# ============================================
# UTILITY ALIASES
# ============================================

# Quick timestamps
alias now='date +"%Y%m%d_%H%M%S"'
alias today='date +"%Y%m%d"'

# Enhanced ls
alias ll='ls -alh --color=auto'
alias lt='ls -alht --color=auto | head -20'  # Latest files

# Process management
alias psg='ps aux | grep -i'
alias killall='pkill -9'

# Network utilities
alias ports='netstat -tulanp 2>/dev/null | grep LISTEN'
alias myip='curl -s ifconfig.me'
alias localip='ip addr show | grep -oP "(?<=inet\s)\d+(\.\d+){3}"'

# Docker shortcuts
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dexec='docker exec -it'
alias dlogs='docker logs -f'
alias dclean='docker system prune -af'

# Security shortcuts
alias scan-ports='nmap -p-'
alias scan-services='nmap -sV -sC'
alias serve='python3 -m http.server'

echo -e "${GREEN}Advanced security functions loaded!${NC}"
echo -e "${BLUE}Type 'help-security' to see available functions${NC}"

# Help function
help-security() {
    echo -e "${BLUE}=== Advanced Security Functions ===${NC}"
    echo
    echo -e "${YELLOW}SSH & Remote Access:${NC}"
    echo "  sshm <user@host>          - SSH with automatic filesystem mount"
    echo "  setup_ssh_monitoring      - Configure SSH login alerts"
    echo
    echo -e "${YELLOW}Docker Security:${NC}"
    echo "  docker-safe-run           - Docker run with security checks"
    echo "  docker-with-cache         - Smart caching for docker volumes"
    echo "  docker-clean <pattern>    - Clean containers by name pattern"
    echo
    echo -e "${YELLOW}Network Tools:${NC}"
    echo "  expose-service <port>     - Expose local service via localhost.run"
    echo "  smb-serve [name]          - Quick SMB server in current directory"
    echo "  tor-array [count] [port]  - Deploy multiple Tor SOCKS proxies"
    echo
    echo -e "${YELLOW}Security Testing:${NC}"
    echo "  detect-404-size <url>     - Detect 404 page size for fuzzing"
    echo "  parallel-scan <target>    - Run multiple scanners in parallel"
    echo
    echo -e "${YELLOW}Utilities:${NC}"
    echo "  run-with-notify <name> <cmd>  - Run command with notification"
    echo "  pass-gen-qr [length]          - Generate password with QR code"
    echo "  secure-temp [prefix]          - Create secure temporary file"
    echo
}