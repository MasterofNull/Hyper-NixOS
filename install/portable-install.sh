#!/bin/sh
# Portable installer for Hyper-NixOS
# Works across different Unix-like systems

set -eu

# Installer configuration
SCRIPT_NAME="$(basename "$0")"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
INSTALL_SYSCONFDIR="${INSTALL_SYSCONFDIR:-/etc}"
INSTALL_LOCALSTATEDIR="${INSTALL_LOCALSTATEDIR:-/var}"
INSTALL_MODE="system"  # system or user
DRY_RUN=0
VERBOSE=0

# Platform detection
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
INIT_SYSTEM=""

# Color output
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Logging
log() { printf '%s\n' "$*"; }
log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
log_success() { printf "${GREEN}[OK]${NC} %s\n" "$*"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
die() { log_error "$@"; exit 1; }

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        if [ "$INSTALL_MODE" = "system" ]; then
            die "System installation requires root privileges. Run with sudo or as root."
        fi
    fi
}

# Detect init system
detect_init_system() {
    if [ -d /run/systemd/system ]; then
        INIT_SYSTEM="systemd"
    elif [ -f /sbin/openrc ]; then
        INIT_SYSTEM="openrc"
    elif [ -f /etc/init.d/cron ] && [ ! -h /etc/init.d/cron ]; then
        INIT_SYSTEM="sysvinit"
    elif [ "$(uname)" = "Darwin" ]; then
        INIT_SYSTEM="launchd"
    elif [ "$(uname)" = "FreeBSD" ]; then
        INIT_SYSTEM="rc"
    else
        INIT_SYSTEM="unknown"
    fi
    log_info "Detected init system: $INIT_SYSTEM"
}

# Detect package manager
detect_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    elif command -v apk >/dev/null 2>&1; then
        echo "apk"
    elif command -v brew >/dev/null 2>&1; then
        echo "brew"
    elif command -v pkg >/dev/null 2>&1; then
        echo "pkg"
    else
        echo "unknown"
    fi
}

# Install dependencies
install_dependencies() {
    local pkg_manager
    pkg_manager=$(detect_package_manager)
    
    log_info "Installing dependencies using $pkg_manager..."
    
    case "$pkg_manager" in
        apt)
            apt-get update
            apt-get install -y \
                qemu-system-x86 \
                libvirt-daemon-system \
                libvirt-clients \
                bridge-utils \
                curl \
                jq
            ;;
        yum|dnf)
            $pkg_manager install -y \
                qemu-kvm \
                libvirt \
                libvirt-client \
                bridge-utils \
                curl \
                jq
            ;;
        pacman)
            pacman -Sy --noconfirm \
                qemu \
                libvirt \
                bridge-utils \
                curl \
                jq
            ;;
        apk)
            apk add --no-cache \
                qemu-system-x86_64 \
                libvirt-daemon \
                bridge-utils \
                curl \
                jq
            ;;
        brew)
            brew install \
                qemu \
                libvirt \
                curl \
                jq
            ;;
        *)
            log_warn "Unknown package manager. Please install dependencies manually:"
            log_warn "  - QEMU/KVM"
            log_warn "  - libvirt"
            log_warn "  - bridge-utils"
            log_warn "  - curl"
            log_warn "  - jq"
            ;;
    esac
}

# Create directories
create_directories() {
    log_info "Creating directories..."
    
    # System directories
    if [ "$INSTALL_MODE" = "system" ]; then
        install -d -m 755 "$INSTALL_PREFIX/bin"
        install -d -m 755 "$INSTALL_PREFIX/lib/hypervisor"
        install -d -m 755 "$INSTALL_SYSCONFDIR/hypervisor"
        install -d -m 755 "$INSTALL_SYSCONFDIR/hypervisor/scripts"
        install -d -m 755 "$INSTALL_LOCALSTATEDIR/lib/hypervisor"
        install -d -m 755 "$INSTALL_LOCALSTATEDIR/log/hypervisor"
    else
        # User installation
        install -d -m 755 "$HOME/.local/bin"
        install -d -m 755 "$HOME/.local/lib/hypervisor"
        install -d -m 755 "$HOME/.config/hypervisor"
        install -d -m 755 "$HOME/.local/share/hypervisor"
        install -d -m 755 "$HOME/.cache/hypervisor/logs"
    fi
}

# Install binaries
install_binaries() {
    log_info "Installing binaries..."
    
    local bin_dir="$INSTALL_PREFIX/bin"
    if [ "$INSTALL_MODE" = "user" ]; then
        bin_dir="$HOME/.local/bin"
    fi
    
    # Find and install executables
    if [ -d "bin" ]; then
        for binary in bin/*; do
            if [ -f "$binary" ] && [ -x "$binary" ]; then
                local name
                name=$(basename "$binary")
                log_info "  Installing $name"
                install -m 755 "$binary" "$bin_dir/$name"
            fi
        done
    fi
}

# Install scripts
install_scripts() {
    log_info "Installing scripts..."
    
    local script_dir="$INSTALL_SYSCONFDIR/hypervisor/scripts"
    if [ "$INSTALL_MODE" = "user" ]; then
        script_dir="$HOME/.config/hypervisor/scripts"
    fi
    
    if [ -d "scripts" ]; then
        # Install all scripts
        find scripts -type f -name "*.sh" | while IFS= read -r script; do
            local rel_path="${script#scripts/}"
            local dest_dir="$script_dir/$(dirname "$rel_path")"
            install -d -m 755 "$dest_dir"
            install -m 755 "$script" "$dest_dir/"
        done
    fi
}

# Install configuration
install_config() {
    log_info "Installing configuration..."
    
    local config_dir="$INSTALL_SYSCONFDIR/hypervisor"
    if [ "$INSTALL_MODE" = "user" ]; then
        config_dir="$HOME/.config/hypervisor"
    fi
    
    # Install default config
    if [ -f "config/hypervisor.toml" ]; then
        if [ -f "$config_dir/hypervisor.toml" ]; then
            log_warn "Configuration already exists, installing as .new"
            install -m 644 "config/hypervisor.toml" "$config_dir/hypervisor.toml.new"
        else
            install -m 644 "config/hypervisor.toml" "$config_dir/"
        fi
    fi
}

# Install systemd service
install_systemd_service() {
    if [ "$INIT_SYSTEM" != "systemd" ] || [ "$INSTALL_MODE" = "user" ]; then
        return 0
    fi
    
    log_info "Installing systemd services..."
    
    cat > /etc/systemd/system/hypervisor-api.service <<EOF
[Unit]
Description=Hyper-NixOS API Server
After=network.target libvirtd.service
Wants=libvirtd.service

[Service]
Type=notify
ExecStart=$INSTALL_PREFIX/bin/hypervisor-api
Restart=always
RestartSec=5
User=hypervisor
Group=hypervisor
Environment="HYPERVISOR_CONFIG=$INSTALL_SYSCONFDIR/hypervisor/hypervisor.toml"

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_LOCALSTATEDIR/lib/hypervisor

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    log_success "Systemd service installed"
}

# Install OpenRC service
install_openrc_service() {
    if [ "$INIT_SYSTEM" != "openrc" ] || [ "$INSTALL_MODE" = "user" ]; then
        return 0
    fi
    
    log_info "Installing OpenRC service..."
    
    cat > /etc/init.d/hypervisor-api <<'EOF'
#!/sbin/openrc-run

name="Hyper-NixOS API"
description="Hyper-NixOS API Server"
command="/usr/local/bin/hypervisor-api"
command_args=""
command_user="hypervisor:hypervisor"
pidfile="/run/${RC_SVCNAME}.pid"
start_stop_daemon_args="--background --make-pidfile"

depend() {
    need net
    after libvirtd
}

start_pre() {
    checkpath -d -m 0755 -o hypervisor:hypervisor /var/lib/hypervisor
    checkpath -d -m 0755 -o hypervisor:hypervisor /var/log/hypervisor
}
EOF
    
    chmod +x /etc/init.d/hypervisor-api
    log_success "OpenRC service installed"
}

# Create user and group
create_user() {
    if [ "$INSTALL_MODE" = "user" ]; then
        return 0
    fi
    
    log_info "Creating hypervisor user and group..."
    
    # Create group
    if ! getent group hypervisor >/dev/null 2>&1; then
        case "$OS" in
            linux)
                groupadd -r hypervisor
                ;;
            freebsd|openbsd|netbsd)
                pw groupadd hypervisor
                ;;
            darwin)
                dscl . -create /Groups/hypervisor
                ;;
        esac
    fi
    
    # Create user
    if ! getent passwd hypervisor >/dev/null 2>&1; then
        case "$OS" in
            linux)
                useradd -r -g hypervisor -d /var/lib/hypervisor -s /bin/false hypervisor
                ;;
            freebsd|openbsd|netbsd)
                pw useradd hypervisor -g hypervisor -d /var/lib/hypervisor -s /usr/sbin/nologin
                ;;
            darwin)
                dscl . -create /Users/hypervisor
                dscl . -create /Users/hypervisor UserShell /usr/bin/false
                ;;
        esac
    fi
    
    # Add to libvirt group
    case "$OS" in
        linux)
            usermod -a -G libvirt,kvm hypervisor 2>/dev/null || true
            ;;
    esac
}

# Set permissions
set_permissions() {
    if [ "$INSTALL_MODE" = "user" ]; then
        return 0
    fi
    
    log_info "Setting permissions..."
    
    chown -R hypervisor:hypervisor "$INSTALL_LOCALSTATEDIR/lib/hypervisor"
    chown -R hypervisor:hypervisor "$INSTALL_LOCALSTATEDIR/log/hypervisor"
    chmod 750 "$INSTALL_LOCALSTATEDIR/lib/hypervisor"
    chmod 750 "$INSTALL_LOCALSTATEDIR/log/hypervisor"
}

# Post-install message
post_install_message() {
    log_success "Installation completed!"
    echo
    echo "Next steps:"
    
    if [ "$INSTALL_MODE" = "system" ]; then
        echo "1. Start the service:"
        case "$INIT_SYSTEM" in
            systemd)
                echo "   sudo systemctl start hypervisor-api"
                echo "   sudo systemctl enable hypervisor-api"
                ;;
            openrc)
                echo "   sudo rc-service hypervisor-api start"
                echo "   sudo rc-update add hypervisor-api default"
                ;;
            *)
                echo "   Start hypervisor-api manually"
                ;;
        esac
    else
        echo "1. Add $HOME/.local/bin to your PATH:"
        echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    
    echo "2. Configure hypervisor:"
    if [ "$INSTALL_MODE" = "system" ]; then
        echo "   sudo vi $INSTALL_SYSCONFDIR/hypervisor/hypervisor.toml"
    else
        echo "   vi $HOME/.config/hypervisor/hypervisor.toml"
    fi
    
    echo "3. Run the menu:"
    echo "   hypervisor-menu"
    echo
    echo "For documentation, see: https://github.com/hypervisor/docs"
}

# Uninstall function
uninstall() {
    log_info "Uninstalling Hyper-NixOS..."
    
    # Stop services
    if [ "$INIT_SYSTEM" = "systemd" ] && [ "$INSTALL_MODE" = "system" ]; then
        systemctl stop hypervisor-api 2>/dev/null || true
        systemctl disable hypervisor-api 2>/dev/null || true
        rm -f /etc/systemd/system/hypervisor-api.service
        systemctl daemon-reload
    fi
    
    # Remove files
    if [ "$INSTALL_MODE" = "system" ]; then
        rm -rf "$INSTALL_PREFIX/bin/hypervisor-"*
        rm -rf "$INSTALL_PREFIX/lib/hypervisor"
        rm -rf "$INSTALL_SYSCONFDIR/hypervisor"
        rm -rf "$INSTALL_LOCALSTATEDIR/lib/hypervisor"
        rm -rf "$INSTALL_LOCALSTATEDIR/log/hypervisor"
    else
        rm -rf "$HOME/.local/bin/hypervisor-"*
        rm -rf "$HOME/.local/lib/hypervisor"
        rm -rf "$HOME/.config/hypervisor"
        rm -rf "$HOME/.local/share/hypervisor"
        rm -rf "$HOME/.cache/hypervisor"
    fi
    
    log_success "Uninstall completed"
}

# Usage
usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Portable installer for Hyper-NixOS

Options:
    -h, --help              Show this help
    -u, --user              Install for current user only
    -p, --prefix PATH       Installation prefix (default: /usr/local)
    -s, --sysconfdir PATH   System config directory (default: /etc)
    -l, --localstatedir PATH Local state directory (default: /var)
    -d, --deps              Install dependencies
    -n, --dry-run           Show what would be done
    -v, --verbose           Verbose output
    --uninstall             Uninstall Hyper-NixOS

Examples:
    # System-wide installation
    sudo $SCRIPT_NAME

    # User installation
    $SCRIPT_NAME --user

    # Custom prefix
    sudo $SCRIPT_NAME --prefix /opt/hypervisor

    # Install with dependencies
    sudo $SCRIPT_NAME --deps

EOF
}

# Parse arguments
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -u|--user)
                INSTALL_MODE="user"
                shift
                ;;
            -p|--prefix)
                INSTALL_PREFIX="$2"
                shift 2
                ;;
            -s|--sysconfdir)
                INSTALL_SYSCONFDIR="$2"
                shift 2
                ;;
            -l|--localstatedir)
                INSTALL_LOCALSTATEDIR="$2"
                shift 2
                ;;
            -d|--deps)
                INSTALL_DEPS=1
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=1
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            --uninstall)
                UNINSTALL=1
                shift
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done
}

# Main
main() {
    parse_args "$@"
    
    # Check for uninstall
    if [ "${UNINSTALL:-0}" -eq 1 ]; then
        check_root
        uninstall
        exit 0
    fi
    
    log_info "Hyper-NixOS Portable Installer"
    log_info "Platform: $OS ($ARCH)"
    
    # Check permissions
    check_root
    
    # Detect environment
    detect_init_system
    
    # Install dependencies if requested
    if [ "${INSTALL_DEPS:-0}" -eq 1 ]; then
        install_dependencies
    fi
    
    # Create user/group
    create_user
    
    # Install components
    create_directories
    install_binaries
    install_scripts
    install_config
    
    # Install service files
    case "$INIT_SYSTEM" in
        systemd)
            install_systemd_service
            ;;
        openrc)
            install_openrc_service
            ;;
    esac
    
    # Set permissions
    set_permissions
    
    # Show completion message
    post_install_message
}

# Run main
main "$@"