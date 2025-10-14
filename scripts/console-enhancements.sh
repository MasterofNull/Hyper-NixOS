#!/bin/bash
# shellcheck disable=SC2034,SC2154,SC1091
# Console Enhancement Installer
# Advanced terminal features for security operations

set -e

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

CONSOLE_DIR="${CONSOLE_DIR:-$HOME/.security/console}"

# Install Oh My Zsh with security theme
install_oh_my_zsh() {
    echo -e "${CYAN}Installing Oh My Zsh with security enhancements...${NC}"
    
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    
    # Create custom security theme
    cat > "$HOME/.oh-my-zsh/custom/themes/security.zsh-theme" << 'EOF'
# Security-focused ZSH theme
PROMPT='%{$fg_bold[cyan]%}┌─[%{$fg_bold[green]%}%n%{$fg_bold[cyan]%}@%{$fg_bold[green]%}%m%{$fg_bold[cyan]%}]─[%{$fg_bold[blue]%}%~%{$fg_bold[cyan]%}]$(git_prompt_info)$(security_status)
%{$fg_bold[cyan]%}└─>%{$reset_color%} '

RPROMPT='%{$fg[yellow]%}[%*]%{$reset_color%}'

ZSH_THEME_GIT_PROMPT_PREFIX="─[%{$fg_bold[yellow]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$fg_bold[cyan]%}]"
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}✗"
ZSH_THEME_GIT_PROMPT_CLEAN=" %{$fg[green]%}✓"

# Security status indicator
security_status() {
    if [[ -f /tmp/security_alert ]]; then
        echo "%{$fg_bold[red]%}─[SEC:ALERT]%{$reset_color%}"
    elif command -v sec >/dev/null 2>&1 && sec status --quick 2>/dev/null | grep -q "OK"; then
        echo "%{$fg_bold[green]%}─[SEC:OK]%{$reset_color%}"
    else
        echo "%{$fg_bold[yellow]%}─[SEC:?]%{$reset_color%}"
    fi
}
EOF
    
    # Configure .zshrc
    cat > "$HOME/.zshrc.security" << 'EOF'
# Security console configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="security"

# Plugins
plugins=(
    git
    docker
    kubectl
    aws
    terraform
    colored-man-pages
    command-not-found
    extract
    sudo
    history-substring-search
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
)

source $ZSH/oh-my-zsh.sh

# Security aliases
source $HOME/.security/console/aliases.sh

# Advanced completions
source $HOME/.security/console/completions.zsh

# Custom functions
source $HOME/.security/console/functions.sh

# Key bindings
source $HOME/.security/console/keybindings.zsh
EOF
}

# Install advanced plugins
install_zsh_plugins() {
    echo -e "${CYAN}Installing ZSH plugins...${NC}"
    
    local CUSTOM_DIR="$HOME/.oh-my-zsh/custom"
    
    # Syntax highlighting
    if [[ ! -d "$CUSTOM_DIR/plugins/zsh-syntax-highlighting" ]]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
            "$CUSTOM_DIR/plugins/zsh-syntax-highlighting"
    fi
    
    # Auto suggestions
    if [[ ! -d "$CUSTOM_DIR/plugins/zsh-autosuggestions" ]]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions \
            "$CUSTOM_DIR/plugins/zsh-autosuggestions"
    fi
    
    # Completions
    if [[ ! -d "$CUSTOM_DIR/plugins/zsh-completions" ]]; then
        git clone https://github.com/zsh-users/zsh-completions \
            "$CUSTOM_DIR/plugins/zsh-completions"
    fi
}

# Install FZF for fuzzy searching
install_fzf() {
    echo -e "${CYAN}Installing FZF (fuzzy finder)...${NC}"
    
    if ! command -v fzf >/dev/null 2>&1; then
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install --key-bindings --completion --no-update-rc
    fi
    
    # FZF configuration
    cat > "$CONSOLE_DIR/fzf.sh" << 'EOF'
# FZF configuration for security operations
export FZF_DEFAULT_OPTS="
    --height 40%
    --layout=reverse
    --border
    --inline-info
    --color=dark
    --color=fg:-1,bg:-1,hl:#5fff87,fg+:-1,bg+:-1,hl+:#ffaf5f
    --color=info:#af87ff,prompt:#5fff87,pointer:#ff87d7,marker:#ff87d7,spinner:#ff87d7
"

# Security-specific FZF commands
alias fzf-scan='sec scan history | fzf --preview "sec scan show {}"'
alias fzf-alerts='sec alerts list | fzf --preview "sec alerts show {}"'
alias fzf-logs='sec logs | fzf --preview "echo {} | sec logs parse"'

# Interactive security log search
fsec() {
    local log=$(find /var/log -name "*.log" 2>/dev/null | fzf --preview 'tail -n 50 {}')
    [[ -n "$log" ]] && less +F "$log"
}

# Interactive process kill with security context
fkill() {
    local pid=$(ps aux | fzf | awk '{print $2}')
    if [[ -n "$pid" ]]; then
        echo "Security check for PID $pid:"
        sec check process "$pid"
        read -p "Kill process $pid? [y/N] " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] && kill -9 "$pid"
    fi
}

# Interactive container security inspection
fdocker() {
    local container=$(docker ps -a | fzf | awk '{print $1}')
    [[ -n "$container" ]] && sec check container "$container"
}
EOF
}

# Install tmux with security layout
install_tmux_config() {
    echo -e "${CYAN}Installing tmux security configuration...${NC}"
    
    cat > "$HOME/.tmux.conf.security" << 'EOF'
# Security Operations Tmux Configuration

# Prefix key
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Colors and styling
set -g default-terminal "screen-256color"
set -g status-style bg=colour235,fg=colour136
set -g window-status-style fg=colour244
set -g window-status-current-style fg=colour166,bg=default,bright
set -g pane-border-style fg=colour235
set -g pane-active-border-style fg=colour136
set -g message-style bg=colour235,fg=colour166

# Status bar
set -g status-left-length 50
set -g status-right-length 100
set -g status-left "#[fg=green]#H #[fg=black]• #[fg=yellow]#(uname -r) "
set -g status-right "#[fg=cyan]#(sec status --tmux) #[fg=black]• #[fg=yellow]%H:%M:%S"
set -g status-interval 1

# Window naming
set -g automatic-rename on
set -g set-titles on

# Security monitoring layout
bind-key M split-window -h -p 30 'htop' \; \
           split-window -v -p 50 'watch -n 1 sec status' \; \
           select-pane -t 0 \; \
           split-window -v -p 30 'tail -f /var/log/security.log' \; \
           select-pane -t 0

# Quick security commands
bind-key s command-prompt -p "scan target:" "split-window 'sec scan %1'"
bind-key c command-prompt -p "check type:" "split-window 'sec check %1'"
bind-key l split-window -h 'sec logs --tail'
bind-key a split-window -v 'sec alerts'

# Pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Reload config
bind r source-file ~/.tmux.conf \; display-message "Config reloaded!"
EOF
    
    # Create security session script
    cat > "$CONSOLE_DIR/tmux-security-session.sh" << 'EOF'
#!/bin/bash
# Launch tmux security monitoring session

tmux new-session -d -s security -n monitoring
tmux send-keys -t security:monitoring 'htop' C-m
tmux split-window -t security:monitoring -h -p 60
tmux send-keys -t security:monitoring.1 'watch -n 1 sec status' C-m
tmux split-window -t security:monitoring.1 -v -p 50
tmux send-keys -t security:monitoring.2 'sec monitor logs --tail' C-m

tmux new-window -t security -n scanning
tmux send-keys -t security:scanning 'sec scan' C-m

tmux new-window -t security -n analysis
tmux send-keys -t security:analysis 'sec' C-m

tmux select-window -t security:monitoring
tmux attach-session -t security
EOF
    chmod +x "$CONSOLE_DIR/tmux-security-session.sh"
}

# Install advanced aliases and functions
install_aliases_functions() {
    echo -e "${CYAN}Installing advanced aliases and functions...${NC}"
    
    mkdir -p "$CONSOLE_DIR"
    
    # Aliases
    cat > "$CONSOLE_DIR/aliases.sh" << 'EOF'
# Security Console Aliases

# Quick commands
alias s='sec'
alias ss='sec status'
alias sS='sec scan'
alias sc='sec check'
alias sm='sec monitor'
alias sa='sec alerts'
alias sr='sec report'

# Colorized output
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Security-specific
alias ports='netstat -tulanp'
alias listening='lsof -i -P -n | grep LISTEN'
alias established='lsof -i -P -n | grep ESTABLISHED'
alias sockets='ss -tulwn'
alias fw='sudo iptables -L -n -v'
alias fw6='sudo ip6tables -L -n -v'
alias psec='ps auxf | grep -E "(sshd|nginx|apache|mysql|docker)"'
alias logs='journalctl -xe'
alias seclogs='journalctl -u security-* -f'

# Docker security
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dsec='docker ps -q | xargs -I {} sec check container {}'
alias dvuln='docker images -q | xargs -I {} sec scan image {}'

# Network security
alias nmap-quick='nmap -sV -T4 -O -F --version-light'
alias nmap-full='nmap -sC -sV -T4 -O -p- --version-all'
alias tcpdump-http='sudo tcpdump -i any -n -s 0 -A "tcp port 80 or tcp port 443"'
alias tcpdump-dns='sudo tcpdump -i any -n "port 53"'
alias netmon='sudo iftop -i any'

# File integrity
alias modified-today='find . -type f -mtime -1 -ls'
alias modified-hour='find . -type f -mmin -60 -ls'
alias large-files='find . -type f -size +100M -ls | sort -k7 -n'
alias suid-files='find / -perm -4000 -ls 2>/dev/null'
alias world-writable='find / -perm -2 -type f -ls 2>/dev/null'

# Process monitoring
alias top-cpu='ps aux | sort -nrk 3,3 | head -n 10'
alias top-mem='ps aux | sort -nrk 4,4 | head -n 10'
alias zombie='ps aux | grep -E "Z|<defunct>"'

# System resources
alias meminfo='free -h'
alias cpuinfo='lscpu'
alias diskinfo='df -h'
alias mountinfo='mount | column -t'

# Git security
alias git-secrets='git secrets --scan'
alias git-leaks='gitleaks detect'
alias git-signed='git log --show-signature'
EOF
    
    # Functions
    cat > "$CONSOLE_DIR/functions.sh" << 'EOF'
# Security Console Functions

# Extract any archive
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar e "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "'$1' cannot be extracted" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Security scan with notification
scan-notify() {
    local target="${1:-localhost}"
    sec scan "$target" --full
    notify-send "Security Scan Complete" "Target: $target" -u critical
}

# Check all security aspects
check-all() {
    echo "=== System Security Check ==="
    sec check system
    echo -e "\n=== Container Security Check ==="
    sec check containers
    echo -e "\n=== Vulnerability Check ==="
    sec check vulns
    echo -e "\n=== Compliance Check ==="
    sec check compliance
}

# Monitor specific service
monitor-service() {
    local service="$1"
    if [[ -z "$service" ]]; then
        echo "Usage: monitor-service <service-name>"
        return 1
    fi
    watch -n 1 "systemctl status $service; echo; journalctl -u $service -n 20"
}

# Quick incident response
incident() {
    local type="${1:-unknown}"
    echo "Initiating incident response for: $type"
    sec incident create --type "$type" --severity high
    sec monitor start --enhanced
    sec alerts enable --all
}

# Secure file transfer
secure-copy() {
    local source="$1"
    local dest="$2"
    if [[ -z "$source" || -z "$dest" ]]; then
        echo "Usage: secure-copy <source> <destination>"
        return 1
    fi
    rsync -avzP --progress -e "ssh -o StrictHostKeyChecking=yes -o Compression=yes" "$source" "$dest"
}

# Check SSL certificate
check-ssl() {
    local domain="${1:-localhost}"
    local port="${2:-443}"
    echo | openssl s_client -showcerts -servername "$domain" -connect "$domain:$port" 2>/dev/null | \
        openssl x509 -inform pem -noout -text
}

# Generate secure password
genpass() {
    local length="${1:-20}"
    openssl rand -base64 48 | tr -d "=+/" | cut -c1-"$length"
}

# Find listening processes
what-listens() {
    local port="$1"
    if [[ -z "$port" ]]; then
        sudo lsof -i -P -n | grep LISTEN
    else
        sudo lsof -i ":$port" -P -n
    fi
}

# Security-enhanced cd
cd() {
    builtin cd "$@" && {
        # Check for security files in new directory
        [[ -f .security ]] && cat .security
        [[ -f .gitignore ]] && grep -q "secret\|key\|password" .gitignore && \
            echo -e "\033[33mWarning: Directory may contain sensitive files\033[0m"
    }
}

# Quick base64 encode/decode
b64() {
    if [[ "$1" == "-d" ]]; then
        echo "$2" | base64 -d
    else
        echo "$1" | base64
    fi
}

# Watch for file changes
watch-files() {
    local dir="${1:-.}"
    inotifywait -m -r -e modify,create,delete,move "$dir" --format '%w%f %e %T' --timefmt '%Y-%m-%d %H:%M:%S'
}
EOF
}

# Install completions
install_completions() {
    echo -e "${CYAN}Installing advanced completions...${NC}"
    
    cat > "$CONSOLE_DIR/completions.zsh" << 'EOF'
# Security framework ZSH completions

# Main sec command completion
_sec() {
    local -a commands
    commands=(
        'scan:Network and vulnerability scanning'
        'check:System security checking'
        'monitor:Security monitoring'
        'alerts:Alert management'
        'report:Generate security reports'
        'incident:Incident response'
        'fix:Apply security fixes'
        'help:Show help'
    )
    
    _arguments \
        '1: :->command' \
        '2: :->subcommand' \
        '*: :->args'
    
    case $state in
        command)
            _describe 'command' commands
            ;;
        subcommand)
            case $words[2] in
                scan)
                    local -a scan_commands
                    scan_commands=(
                        'network:Network scanning'
                        'web:Web application scanning'
                        'container:Container scanning'
                        'image:Docker image scanning'
                        'quick:Quick scan'
                        'deep:Deep scan'
                    )
                    _describe 'scan command' scan_commands
                    ;;
                check)
                    local -a check_commands
                    check_commands=(
                        'system:System security'
                        'containers:Container security'
                        'vulns:Vulnerabilities'
                        'compliance:Compliance status'
                        'all:All checks'
                    )
                    _describe 'check command' check_commands
                    ;;
                monitor)
                    local -a monitor_commands
                    monitor_commands=(
                        'start:Start monitoring'
                        'stop:Stop monitoring'
                        'status:Monitoring status'
                        'logs:View logs'
                        'events:View events'
                    )
                    _describe 'monitor command' monitor_commands
                    ;;
            esac
            ;;
    esac
}

compdef _sec sec
compdef _sec security

# Docker security completions
_docker_sec() {
    local -a docker_commands
    docker_commands=(
        'scan:Scan container/image'
        'check:Check container security'
        'monitor:Monitor container'
        'quarantine:Quarantine container'
    )
    _describe 'docker security command' docker_commands
}

# Network security completions
_net_sec() {
    local -a net_commands
    net_commands=(
        'scan:Scan network'
        'monitor:Monitor traffic'
        'block:Block IP/port'
        'allow:Allow IP/port'
        'status:Firewall status'
    )
    _describe 'network security command' net_commands
}

# File path completion with security hints
_secure_files() {
    _files
    # Add security warnings for sensitive files
    if [[ "$words[CURRENT]" =~ "(key|secret|password|token)" ]]; then
        echo -e "\n\033[33mWarning: Potential sensitive file\033[0m"
    fi
}
EOF
}

# Install key bindings
install_keybindings() {
    echo -e "${CYAN}Installing key bindings...${NC}"
    
    cat > "$CONSOLE_DIR/keybindings.zsh" << 'EOF'
# Security console key bindings

# Ctrl+S - Quick security status
bindkey -s '^S' 'sec status^M'

# Ctrl+X, Ctrl+S - Security scan
bindkey -s '^X^S' 'sec scan '

# Ctrl+X, Ctrl+C - Security check
bindkey -s '^X^C' 'sec check '

# Ctrl+X, Ctrl+M - Monitor toggle
bindkey -s '^X^M' 'sec monitor status^M'

# Ctrl+X, Ctrl+A - Show alerts
bindkey -s '^X^A' 'sec alerts^M'

# Ctrl+X, Ctrl+L - Show security logs
bindkey -s '^X^L' 'sec logs --tail^M'

# Ctrl+R - Enhanced history search with fzf
bindkey '^R' fzf-history-widget

# Alt+C - cd with security check
bindkey '\ec' fzf-cd-widget

# Ctrl+T - File search with security info
bindkey '^T' fzf-file-widget
EOF
}

# Install notification system
install_notifications() {
    echo -e "${CYAN}Installing notification system...${NC}"
    
    cat > "$CONSOLE_DIR/notify.sh" << 'EOF'
#!/bin/bash
# Security notification system

notify_security() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"
    local icon="${4:-security}"
    
    # Desktop notification
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$message" -u "$urgency" -i "$icon"
    fi
    
    # Terminal notification (if in tmux)
    if [[ -n "$TMUX" ]]; then
        tmux display-message "$title: $message"
    fi
    
    # Log notification
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $urgency: $title - $message" >> "$HOME/.security/notifications.log"
}

# Watch for security events
watch_security_events() {
    tail -f /var/log/security.log 2>/dev/null | while read -r line; do
        if echo "$line" | grep -qE "(CRITICAL|ALERT|ERROR)"; then
            notify_security "Security Alert" "$line" "critical" "dialog-error"
        fi
    done
}
EOF
    chmod +x "$CONSOLE_DIR/notify.sh"
}

# Main installation
main() {
    echo -e "${BOLD}${CYAN}Security Console Enhancement Installer${NC}"
    echo "========================================"
    echo
    
    # Create directories
    mkdir -p "$CONSOLE_DIR"
    
    # Install components
    install_oh_my_zsh
    install_zsh_plugins
    install_fzf
    install_tmux_config
    install_aliases_functions
    install_completions
    install_keybindings
    install_notifications
    
    # Create activation script
    cat > "$CONSOLE_DIR/activate.sh" << EOF
#!/bin/bash
# Activate security console enhancements

# Source all components
source "$CONSOLE_DIR/aliases.sh"
source "$CONSOLE_DIR/functions.sh"
source "$CONSOLE_DIR/fzf.sh"

# Set up notifications
"$CONSOLE_DIR/notify.sh" &

# Show status
echo -e "${GREEN}Security console enhancements activated!${NC}"
echo "Features enabled:"
echo "  • Advanced auto-completion"
echo "  • Fuzzy search (fzf)"
echo "  • Security aliases and functions"
echo "  • Key bindings"
echo "  • Notifications"
echo ""
echo "Try: ${CYAN}fsec${NC} for log search, ${CYAN}fkill${NC} for process management"
echo "     ${CYAN}Ctrl+S${NC} for quick status, ${CYAN}Ctrl+X,Ctrl+S${NC} for scanning"
EOF
    chmod +x "$CONSOLE_DIR/activate.sh"
    
    echo
    echo -e "${GREEN}Installation complete!${NC}"
    echo
    echo "To activate console enhancements:"
    echo "  source $CONSOLE_DIR/activate.sh"
    echo
    echo "For ZSH with Oh My Zsh:"
    echo "  cp ~/.zshrc ~/.zshrc.backup"
    echo "  cp ~/.zshrc.security ~/.zshrc"
    echo "  source ~/.zshrc"
    echo
    echo "For tmux security session:"
    echo "  $CONSOLE_DIR/tmux-security-session.sh"
}

# Run main
main "$@"