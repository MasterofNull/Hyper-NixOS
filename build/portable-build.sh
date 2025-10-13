#!/bin/sh
# Portable build script for Hyper-NixOS
# POSIX-compliant for maximum compatibility

set -eu

# Script configuration
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(CDPATH="" cd -- "$(dirname -- "$0")" && pwd -P)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
BUILD_TYPE="release"
TARGET_ARCH=""
TARGET_OS=""
CROSS_COMPILE=0
STATIC_BUILD=0
VERBOSE=0

# Color output (if terminal supports it)
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    RESET=$(tput sgr0)
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    RESET=""
fi

# Logging functions
log() {
    printf '%s\n' "$*"
}

log_info() {
    log "${BLUE}[INFO]${RESET} $*"
}

log_success() {
    log "${GREEN}[SUCCESS]${RESET} $*"
}

log_warn() {
    log "${YELLOW}[WARN]${RESET} $*" >&2
}

log_error() {
    log "${RED}[ERROR]${RESET} $*" >&2
}

die() {
    log_error "$@"
    exit 1
}

# Platform detection
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux" ;;
        Darwin*)    echo "darwin" ;;
        FreeBSD*)   echo "freebsd" ;;
        NetBSD*)    echo "netbsd" ;;
        OpenBSD*)   echo "openbsd" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)       echo "amd64" ;;
        i?86)               echo "386" ;;
        aarch64|arm64)      echo "arm64" ;;
        armv7*|armv6*)      echo "arm" ;;
        riscv64)            echo "riscv64" ;;
        ppc64le)            echo "ppc64le" ;;
        s390x)              echo "s390x" ;;
        *)                  echo "unknown" ;;
    esac
}

# Check for required commands
check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

check_requirements() {
    log_info "Checking build requirements..."
    
    missing=""
    
    # Check for essential tools
    for cmd in make cc; do
        if ! check_command "$cmd"; then
            missing="$missing $cmd"
        fi
    done
    
    # Check for language-specific tools
    if [ -d "$PROJECT_ROOT/tools/rust-lib" ]; then
        if ! check_command "cargo"; then
            missing="$missing cargo"
        fi
    fi
    
    if [ -d "$PROJECT_ROOT/api" ]; then
        if ! check_command "go"; then
            missing="$missing go"
        fi
    fi
    
    if [ -n "$missing" ]; then
        die "Missing required commands:$missing"
    fi
    
    log_success "All requirements satisfied"
}

# Build Rust components
build_rust() {
    if [ ! -d "$PROJECT_ROOT/tools/rust-lib" ]; then
        log_info "No Rust components found, skipping..."
        return 0
    fi
    
    log_info "Building Rust components..."
    cd "$PROJECT_ROOT/tools/rust-lib"
    
    # Set target if cross-compiling
    target_flag=""
    if [ -n "$TARGET_ARCH" ] && [ -n "$TARGET_OS" ]; then
        rust_target="${TARGET_ARCH}-unknown-${TARGET_OS}-"
        case "$TARGET_OS" in
            linux)  rust_target="${rust_target}gnu" ;;
            darwin) rust_target="${rust_target}darwin" ;;
            *)      rust_target="${rust_target}${TARGET_OS}" ;;
        esac
        
        if [ "$STATIC_BUILD" -eq 1 ]; then
            rust_target="${TARGET_ARCH}-unknown-${TARGET_OS}-musl"
        fi
        
        target_flag="--target $rust_target"
        
        # Install target if needed
        if ! rustup target list --installed | grep -q "$rust_target"; then
            log_info "Installing Rust target: $rust_target"
            rustup target add "$rust_target" || die "Failed to add Rust target"
        fi
    fi
    
    # Build flags
    build_flags=""
    if [ "$BUILD_TYPE" = "release" ]; then
        build_flags="--release"
    fi
    
    if [ "$VERBOSE" -eq 1 ]; then
        build_flags="$build_flags --verbose"
    fi
    
    # Build
    log_info "Running: cargo build $build_flags $target_flag"
    cargo build $build_flags $target_flag || die "Rust build failed"
    
    log_success "Rust components built successfully"
}

# Build Go components
build_go() {
    if [ ! -d "$PROJECT_ROOT/api" ]; then
        log_info "No Go components found, skipping..."
        return 0
    fi
    
    log_info "Building Go components..."
    cd "$PROJECT_ROOT/api"
    
    # Set environment for cross-compilation
    if [ -n "$TARGET_ARCH" ]; then
        export GOARCH="$TARGET_ARCH"
    fi
    if [ -n "$TARGET_OS" ]; then
        export GOOS="$TARGET_OS"
    fi
    
    # Static build flags
    ldflags="-s -w"
    if [ "$STATIC_BUILD" -eq 1 ]; then
        export CGO_ENABLED=0
        ldflags="$ldflags -extldflags '-static'"
    fi
    
    # Build
    build_cmd="go build -ldflags=\"$ldflags\""
    if [ "$BUILD_TYPE" = "release" ]; then
        build_cmd="$build_cmd -trimpath"
    fi
    if [ "$VERBOSE" -eq 1 ]; then
        build_cmd="$build_cmd -v"
    fi
    
    log_info "Running: $build_cmd -o hypervisor-api"
    eval "$build_cmd -o hypervisor-api" || die "Go build failed"
    
    log_success "Go components built successfully"
}

# Build container images
build_containers() {
    if ! check_command "docker" && ! check_command "podman"; then
        log_warn "No container runtime found, skipping container build..."
        return 0
    fi
    
    # Use podman if available, otherwise docker
    if check_command "podman"; then
        container_cmd="podman"
    else
        container_cmd="docker"
    fi
    
    log_info "Building container images with $container_cmd..."
    
    # Build multi-arch images if possible
    if $container_cmd buildx version >/dev/null 2>&1; then
        log_info "Using buildx for multi-arch build"
        platforms="linux/amd64,linux/arm64"
        
        if [ -n "$TARGET_ARCH" ]; then
            platforms="linux/$TARGET_ARCH"
        fi
        
        $container_cmd buildx build \
            --platform "$platforms" \
            --tag "hypervisor:latest" \
            --tag "hypervisor:$("$SCRIPT_DIR/version.sh")" \
            "$PROJECT_ROOT"
    else
        # Fallback to regular build
        $container_cmd build \
            --tag "hypervisor:latest" \
            --tag "hypervisor:$("$SCRIPT_DIR/version.sh")" \
            "$PROJECT_ROOT"
    fi
    
    log_success "Container images built successfully"
}

# Package build artifacts
package_artifacts() {
    log_info "Packaging build artifacts..."
    
    version="$("$SCRIPT_DIR/version.sh" 2>/dev/null || echo "dev")"
    os="${TARGET_OS:-$(detect_os)}"
    arch="${TARGET_ARCH:-$(detect_arch)}"
    
    package_name="hypervisor-${version}-${os}-${arch}"
    package_dir="$PROJECT_ROOT/dist/$package_name"
    
    # Create package directory
    mkdir -p "$package_dir/bin"
    mkdir -p "$package_dir/scripts"
    mkdir -p "$package_dir/config"
    
    # Copy binaries
    if [ -d "$PROJECT_ROOT/tools/rust-lib/target" ]; then
        find "$PROJECT_ROOT/tools/rust-lib/target" -type f -perm -u+x -name "hypervisor-*" \
            -not -path "*/deps/*" -not -path "*/build/*" \
            -exec cp {} "$package_dir/bin/" \;
    fi
    
    if [ -f "$PROJECT_ROOT/api/hypervisor-api" ]; then
        cp "$PROJECT_ROOT/api/hypervisor-api" "$package_dir/bin/"
    fi
    
    # Copy scripts
    cp -r "$PROJECT_ROOT/scripts"/* "$package_dir/scripts/" 2>/dev/null || true
    
    # Copy config
    cp "$PROJECT_ROOT/config"/*.toml "$package_dir/config/" 2>/dev/null || true
    
    # Create archive
    cd "$PROJECT_ROOT/dist"
    tar_file="${package_name}.tar.gz"
    log_info "Creating archive: $tar_file"
    tar czf "$tar_file" "$package_name"
    
    # Create checksums
    if check_command "sha256sum"; then
        sha256sum "$tar_file" > "${tar_file}.sha256"
    elif check_command "shasum"; then
        shasum -a 256 "$tar_file" > "${tar_file}.sha256"
    fi
    
    log_success "Package created: dist/$tar_file"
}

# Show usage
usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Portable build script for Hyper-NixOS

Options:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -t, --type TYPE         Build type: debug, release (default: release)
    -a, --arch ARCH         Target architecture (default: auto-detect)
    -o, --os OS             Target OS (default: auto-detect)
    -s, --static            Build static binaries
    -c, --container         Build container images
    --cross                 Enable cross-compilation
    --clean                 Clean build artifacts before building

Examples:
    # Build for current platform
    $SCRIPT_NAME

    # Cross-compile for ARM64 Linux
    $SCRIPT_NAME --arch arm64 --os linux --cross

    # Build static binaries
    $SCRIPT_NAME --static

    # Build everything including containers
    $SCRIPT_NAME --container

Supported architectures: amd64, arm64, arm, riscv64, ppc64le, s390x
Supported OS: linux, darwin, freebsd, netbsd, openbsd

EOF
}

# Parse command line arguments
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -t|--type)
                BUILD_TYPE="$2"
                shift 2
                ;;
            -a|--arch)
                TARGET_ARCH="$2"
                shift 2
                ;;
            -o|--os)
                TARGET_OS="$2"
                shift 2
                ;;
            -s|--static)
                STATIC_BUILD=1
                shift
                ;;
            -c|--container)
                BUILD_CONTAINERS=1
                shift
                ;;
            --cross)
                CROSS_COMPILE=1
                shift
                ;;
            --clean)
                CLEAN_BUILD=1
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Clean build artifacts
clean_build() {
    log_info "Cleaning build artifacts..."
    
    # Clean Rust
    if [ -d "$PROJECT_ROOT/tools/rust-lib" ]; then
        cd "$PROJECT_ROOT/tools/rust-lib"
        cargo clean 2>/dev/null || true
    fi
    
    # Clean Go
    if [ -d "$PROJECT_ROOT/api" ]; then
        cd "$PROJECT_ROOT/api"
        go clean -cache -modcache 2>/dev/null || true
        rm -f hypervisor-api
    fi
    
    # Clean dist
    rm -rf "$PROJECT_ROOT/dist"
    
    log_success "Clean complete"
}

# Main build process
main() {
    parse_args "$@"
    
    # Display build configuration
    log_info "Build configuration:"
    log_info "  OS: ${TARGET_OS:-$(detect_os)}"
    log_info "  Arch: ${TARGET_ARCH:-$(detect_arch)}"
    log_info "  Type: $BUILD_TYPE"
    log_info "  Static: $STATIC_BUILD"
    
    # Clean if requested
    if [ "${CLEAN_BUILD:-0}" -eq 1 ]; then
        clean_build
    fi
    
    # Check requirements
    check_requirements
    
    # Build components
    build_rust
    build_go
    
    # Build containers if requested
    if [ "${BUILD_CONTAINERS:-0}" -eq 1 ]; then
        build_containers
    fi
    
    # Package artifacts
    package_artifacts
    
    log_success "Build completed successfully!"
}

# Run main function
main "$@"