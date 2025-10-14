#!/usr/bin/env bash
# SSH Login Monitoring Script
# Monitors and alerts on SSH connections

# Check if running in SSH session
if [[ -n "$SSH_CONNECTION" ]]; then
    # Parse connection details
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    CLIENT_IP=$(echo "$SSH_CONNECTION" | awk '{print $1}')
    CLIENT_PORT=$(echo "$SSH_CONNECTION" | awk '{print $2}')
    SERVER_IP=$(echo "$SSH_CONNECTION" | awk '{print $3}')
    SERVER_PORT=$(echo "$SSH_CONNECTION" | awk '{print $4}')
    
    # Log directory
    LOG_DIR="/var/log/security"
    LOG_FILE="$LOG_DIR/ssh-monitor.log"
    
    # Create log directory if it doesn't exist
    [[ -d "$LOG_DIR" ]] || sudo mkdir -p "$LOG_DIR"
    
    # Log the connection
    echo "[$TIMESTAMP] SSH Login - User: $USER, From: $CLIENT_IP:$CLIENT_PORT, To: $SERVER_IP:$SERVER_PORT, TTY: $SSH_TTY" | sudo tee -a "$LOG_FILE" >/dev/null
    
    # Check if IP is whitelisted
    WHITELIST_FILE="/etc/ssh/whitelist.ips"
    IS_WHITELISTED=false
    
    if [[ -f "$WHITELIST_FILE" ]]; then
        while IFS= read -r allowed_ip; do
            [[ -z "$allowed_ip" ]] && continue
            [[ "$allowed_ip" =~ ^# ]] && continue
            
            if [[ "$CLIENT_IP" == "$allowed_ip" ]] || [[ "$CLIENT_IP" =~ ^${allowed_ip%.*} ]]; then
                IS_WHITELISTED=true
                break
            fi
        done < "$WHITELIST_FILE"
    fi
    
    # Send notifications if not whitelisted
    if [[ "$IS_WHITELISTED" == "false" ]]; then
        # Desktop notification (if available)
        if command -v notify-send &> /dev/null && [[ -n "$DISPLAY" ]]; then
            notify-send "SSH Login Alert" "Connection from $CLIENT_IP" -u critical -i security-high
        fi
        
        # System log
        logger -t ssh-login -p auth.warning "SSH login from non-whitelisted IP: $CLIENT_IP"
        
        # Execute notification script if available
        if [[ -x "/opt/scripts/automation/notify.sh" ]]; then
            /opt/scripts/automation/notify.sh "SSH Login Alert" "SSH connection from $CLIENT_IP (User: $USER)" "warning"
        fi
    fi
    
    # Export for use in shell
    export SSH_CLIENT_IP="$CLIENT_IP"
    export SSH_LOGIN_TIME="$TIMESTAMP"
fi

# Function to show recent SSH logins
ssh_login_history() {
    local count=${1:-10}
    local log_file="/var/log/security/ssh-monitor.log"
    
    if [[ -f "$log_file" ]]; then
        echo "Recent SSH logins (last $count):"
        sudo tail -n "$count" "$log_file"
    else
        echo "No SSH login history found."
    fi
}

# Function to check current SSH sessions
ssh_active_sessions() {
    echo "Active SSH sessions:"
    who | grep -E 'pts/|tty' | while read -r line; do
        user=$(echo "$line" | awk '{print $1}')
        tty=$(echo "$line" | awk '{print $2}')
        from=$(echo "$line" | awk '{print $5}' | tr -d '()')
        
        echo "  User: $user, TTY: $tty, From: $from"
    done
}

# Export functions for use
export -f ssh_login_history
export -f ssh_active_sessions