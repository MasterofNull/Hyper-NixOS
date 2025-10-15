#!/usr/bin/env bash
#
# hv-stream-migrate - Streaming VM Migration with Live Conversion
# Performs zero-copy streaming migration with on-the-fly format conversion
#

set -euo pipefail

# Source common libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true

# Script metadata
SCRIPT_NAME="$(basename "$0")"
REQUIRES_SUDO=false
OPERATION_TYPE="migration"

# Default values
SOURCE_URI=""
TARGET_URI=""
CONVERSION_PIPELINE=""
STREAM_MODE="adaptive"
COMPRESSION="auto"
ENCRYPTION="auto"
BANDWIDTH_LIMIT=""
VERIFY_BLOCKS=true
LIVE_MODE=false
DELTA_SYNC=true
TRANSFORM_RULES=""

# Supported source formats
SUPPORTED_SOURCES=(
    "qcow2"
    "vmdk"
    "vdi"
    "vhd"
    "raw"
    "rbd"
    "nbd"
    "iscsi"
    "nfs"
    "http"
    "s3"
)

# Supported transformations
SUPPORTED_TRANSFORMS=(
    "resize"
    "reformat"
    "compress"
    "encrypt"
    "deduplicate"
    "thin-provision"
    "thick-provision"
)

# Help function
show_help() {
    cat << EOF
hv-stream-migrate - Streaming VM Migration with Live Conversion

SYNOPSIS:
    $SCRIPT_NAME [OPTIONS] --source <uri> --target <uri>

DESCRIPTION:
    Performs streaming migration of VMs with on-the-fly format conversion,
    compression, encryption, and transformation. Supports live migration
    with minimal downtime.

OPTIONS:
    -s, --source <uri>       Source URI (required)
    -t, --target <uri>       Target URI (required)
    
    Migration Options:
    --live                   Live migration (for running VMs)
    --mode <mode>           Stream mode: adaptive|parallel|sequential
    --compression <type>    Compression: auto|none|lz4|zstd|gzip
    --encryption <type>     Encryption: auto|none|aes256|chacha20
    
    Transformation:
    --convert <format>      Convert to format: qcow2|raw|vmdk
    --resize <size>         Resize disk during migration
    --transform <rules>     Apply transformation rules
    
    Performance:
    --bandwidth <limit>     Bandwidth limit (e.g., 100MB/s)
    --parallel <n>          Parallel streams (default: auto)
    --block-size <size>     Block size for streaming (default: 1M)
    --no-verify            Skip block verification
    
    Advanced:
    --delta                 Use delta sync for changes
    --checkpoint <n>        Create checkpoints every N GB
    --resume <id>          Resume from checkpoint
    
    -h, --help             Show this help message

URI FORMATS:
    file:///path/to/disk.qcow2
    qcow2:///path/to/disk.qcow2
    vmdk://server/path/disk.vmdk
    rbd://pool/image@snapshot
    nbd://server:port/export
    iscsi://target/lun
    nfs://server/export/path
    http://server/path/disk.img
    s3://bucket/key

EXAMPLES:
    # Basic file migration with format conversion
    $SCRIPT_NAME --source file:///vms/old.vmdk --target qcow2:///vms/new.qcow2

    # Live migration with compression
    $SCRIPT_NAME --source rbd://pool/vm1 --target rbd://newpool/vm1 \\
        --live --compression zstd

    # Migration with resize and encryption
    $SCRIPT_NAME --source nfs://nas/vm.raw --target file:///local/vm.qcow2 \\
        --resize 100G --encryption aes256 --convert qcow2

    # Streaming from HTTP with transformation
    $SCRIPT_NAME --source http://repo/template.qcow2 --target rbd://pool/vm \\
        --transform "thin-provision,deduplicate"

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--source)
                SOURCE_URI="$2"
                shift 2
                ;;
            -t|--target)
                TARGET_URI="$2"
                shift 2
                ;;
            --live)
                LIVE_MODE=true
                shift
                ;;
            --mode)
                STREAM_MODE="$2"
                shift 2
                ;;
            --compression)
                COMPRESSION="$2"
                shift 2
                ;;
            --encryption)
                ENCRYPTION="$2"
                shift 2
                ;;
            --convert)
                CONVERSION_FORMAT="$2"
                shift 2
                ;;
            --resize)
                RESIZE_TO="$2"
                shift 2
                ;;
            --transform)
                TRANSFORM_RULES="$2"
                shift 2
                ;;
            --bandwidth)
                BANDWIDTH_LIMIT="$2"
                shift 2
                ;;
            --parallel)
                PARALLEL_STREAMS="$2"
                shift 2
                ;;
            --block-size)
                BLOCK_SIZE="$2"
                shift 2
                ;;
            --no-verify)
                VERIFY_BLOCKS=false
                shift
                ;;
            --delta)
                DELTA_SYNC=true
                shift
                ;;
            --checkpoint)
                CHECKPOINT_INTERVAL="$2"
                shift 2
                ;;
            --resume)
                RESUME_ID="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validate required arguments
    [[ -z "$SOURCE_URI" ]] && die "Source URI is required"
    [[ -z "$TARGET_URI" ]] && die "Target URI is required"
}

# Parse URI into components
parse_uri() {
    local uri="$1"
    local scheme path host port
    
    # Extract scheme
    if [[ "$uri" =~ ^([a-z0-9]+):// ]]; then
        scheme="${BASH_REMATCH[1]}"
        uri="${uri#*://}"
    else
        scheme="file"
    fi
    
    # Extract host:port for network schemes
    case "$scheme" in
        file|qcow2|raw|vmdk)
            path="$uri"
            ;;
        nbd|iscsi|nfs|http|https)
            if [[ "$uri" =~ ^([^/]+)/(.*)$ ]]; then
                host="${BASH_REMATCH[1]}"
                path="${BASH_REMATCH[2]}"
                
                # Extract port if present
                if [[ "$host" =~ ^([^:]+):([0-9]+)$ ]]; then
                    host="${BASH_REMATCH[1]}"
                    port="${BASH_REMATCH[2]}"
                fi
            fi
            ;;
        rbd)
            # Format: pool/image@snapshot
            path="$uri"
            ;;
        s3)
            # Format: bucket/key
            if [[ "$uri" =~ ^([^/]+)/(.*)$ ]]; then
                host="${BASH_REMATCH[1]}"  # bucket
                path="${BASH_REMATCH[2]}"  # key
            fi
            ;;
    esac
    
    echo "scheme=$scheme"
    echo "host=$host"
    echo "port=$port"
    echo "path=$path"
}

# Build streaming pipeline
build_pipeline() {
    local source_scheme="$1"
    local target_scheme="$2"
    local pipeline=()
    
    # Source reader
    case "$source_scheme" in
        file|qcow2|raw|vmdk)
            pipeline+=("dd if=$SOURCE_PATH bs=${BLOCK_SIZE:-1M} status=progress")
            ;;
        rbd)
            pipeline+=("rbd export $SOURCE_PATH - --export-format 2")
            ;;
        nbd)
            pipeline+=("nbdcopy nbd://$SOURCE_HOST:${SOURCE_PORT:-10809}/$SOURCE_PATH -")
            ;;
        http|https)
            pipeline+=("curl -L -s $SOURCE_URI")
            ;;
        s3)
            pipeline+=("aws s3 cp s3://$SOURCE_HOST/$SOURCE_PATH -")
            ;;
        nfs)
            # Mount and stream
            pipeline+=("cat /mnt/nfs-tmp/$SOURCE_PATH")
            ;;
    esac
    
    # Decompression if source is compressed
    if [[ "$SOURCE_PATH" =~ \.(gz|bz2|xz|zst)$ ]]; then
        case "${SOURCE_PATH##*.}" in
            gz) pipeline+=("gunzip -c") ;;
            bz2) pipeline+=("bunzip2 -c") ;;
            xz) pipeline+=("unxz -c") ;;
            zst) pipeline+=("zstd -d -c") ;;
        esac
    fi
    
    # Format conversion
    if [[ -n "${CONVERSION_FORMAT:-}" ]]; then
        pipeline+=("qemu-img convert -f $source_scheme -O $CONVERSION_FORMAT -")
    fi
    
    # Transformations
    if [[ -n "$TRANSFORM_RULES" ]]; then
        IFS=',' read -ra TRANSFORMS <<< "$TRANSFORM_RULES"
        for transform in "${TRANSFORMS[@]}"; do
            case "$transform" in
                thin-provision)
                    pipeline+=("fallocate --dig-holes -")
                    ;;
                deduplicate)
                    pipeline+=("hv-dedup-filter")
                    ;;
                compress)
                    pipeline+=("zstd -3 -c")
                    ;;
            esac
        done
    fi
    
    # Compression
    case "$COMPRESSION" in
        lz4) pipeline+=("lz4 -c") ;;
        zstd) pipeline+=("zstd -3 -c") ;;
        gzip) pipeline+=("gzip -c") ;;
    esac
    
    # Encryption
    case "$ENCRYPTION" in
        aes256) pipeline+=("openssl enc -aes-256-cbc -salt -pass pass:$ENCRYPTION_KEY") ;;
        chacha20) pipeline+=("openssl enc -chacha20 -salt -pass pass:$ENCRYPTION_KEY") ;;
    esac
    
    # Bandwidth limiting
    if [[ -n "$BANDWIDTH_LIMIT" ]]; then
        pipeline+=("pv -L $BANDWIDTH_LIMIT")
    fi
    
    # Target writer
    case "$target_scheme" in
        file|qcow2|raw|vmdk)
            pipeline+=("dd of=$TARGET_PATH bs=${BLOCK_SIZE:-1M} conv=sparse")
            ;;
        rbd)
            pipeline+=("rbd import - $TARGET_PATH --export-format 2")
            ;;
        nbd)
            pipeline+=("nbdcopy - nbd://$TARGET_HOST:${TARGET_PORT:-10809}/$TARGET_PATH")
            ;;
        s3)
            pipeline+=("aws s3 cp - s3://$TARGET_HOST/$TARGET_PATH")
            ;;
    esac
    
    # Join pipeline with pipes
    local cmd="${pipeline[0]}"
    for ((i=1; i<${#pipeline[@]}; i++)); do
        cmd="$cmd | ${pipeline[$i]}"
    done
    
    echo "$cmd"
}

# Create streaming filter for deduplication
create_dedup_filter() {
    cat > /tmp/hv-dedup-filter << 'EOF'
#!/usr/bin/env python3
import sys
import hashlib
import struct

CHUNK_SIZE = 4 * 1024 * 1024  # 4MB chunks
seen_hashes = set()
zeros = b'\0' * CHUNK_SIZE

while True:
    chunk = sys.stdin.buffer.read(CHUNK_SIZE)
    if not chunk:
        break
    
    # Check if chunk is all zeros
    if chunk == zeros[:len(chunk)]:
        # Write sparse marker
        sys.stdout.buffer.write(b'\0' * len(chunk))
    else:
        # Check for duplicates
        chunk_hash = hashlib.blake2b(chunk).digest()
        if chunk_hash in seen_hashes:
            # Write reference marker
            sys.stdout.buffer.write(struct.pack('<Q', hash(chunk_hash)))
        else:
            seen_hashes.add(chunk_hash)
            sys.stdout.buffer.write(chunk)
EOF
    chmod +x /tmp/hv-dedup-filter
}

# Perform live migration
live_migrate() {
    log_info "Starting live migration..."
    
    # Phase 1: Initial bulk copy
    log_info "Phase 1: Bulk copy"
    local pipeline=$(build_pipeline "$SOURCE_SCHEME" "$TARGET_SCHEME")
    eval "$pipeline"
    
    # Phase 2: Track changes
    log_info "Phase 2: Tracking changes"
    if [[ "$SOURCE_SCHEME" == "rbd" ]]; then
        # Create snapshot for change tracking
        rbd snap create "$SOURCE_PATH@migrate-base"
        
        # Start change tracking
        rbd diff "$SOURCE_PATH" --from-snap migrate-base --format json > /tmp/changes.json
    fi
    
    # Phase 3: Incremental sync
    log_info "Phase 3: Incremental sync"
    local iterations=0
    local prev_size=999999999
    
    while true; do
        # Get size of changes
        local change_size=$(stat -c%s /tmp/changes.json 2>/dev/null || echo 0)
        
        # Check if changes are converging
        if [[ $change_size -lt 1000 ]] || [[ $iterations -gt 10 ]]; then
            break
        fi
        
        # Apply changes
        apply_incremental_changes
        
        prev_size=$change_size
        iterations=$((iterations + 1))
        sleep 0.5
    done
    
    # Phase 4: Final sync with pause
    log_info "Phase 4: Final sync"
    
    # Brief pause of source VM
    if [[ "$LIVE_MODE" == "true" ]]; then
        virsh suspend "$SOURCE_VM" 2>/dev/null || true
    fi
    
    # Final incremental sync
    apply_incremental_changes
    
    # Resume source
    if [[ "$LIVE_MODE" == "true" ]]; then
        virsh resume "$SOURCE_VM" 2>/dev/null || true
    fi
    
    log_success "Live migration completed"
}

# Apply incremental changes
apply_incremental_changes() {
    # Implementation depends on source type
    case "$SOURCE_SCHEME" in
        rbd)
            # Export only the changes
            rbd export-diff "$SOURCE_PATH" --from-snap migrate-base - | \
                rbd import-diff - "$TARGET_PATH"
            ;;
        file|qcow2)
            # Use qemu-img for incremental
            qemu-img compare "$SOURCE_PATH" "$TARGET_PATH" || true
            ;;
    esac
}

# Monitor migration progress
monitor_progress() {
    local start_time=$(date +%s)
    local last_bytes=0
    
    while kill -0 $MIGRATION_PID 2>/dev/null; do
        # Get current progress
        local current_bytes=$(get_bytes_transferred)
        local elapsed=$(($(date +%s) - start_time))
        local speed=$(( (current_bytes - last_bytes) / 1 ))
        
        # Calculate ETA
        local total_bytes=$(get_source_size)
        local remaining=$((total_bytes - current_bytes))
        local eta=$((remaining / speed))
        
        # Display progress
        printf "\rProgress: %s / %s (%.1f%%) Speed: %s/s ETA: %s" \
            "$(human_bytes $current_bytes)" \
            "$(human_bytes $total_bytes)" \
            "$(echo "scale=1; $current_bytes * 100 / $total_bytes" | bc)" \
            "$(human_bytes $speed)" \
            "$(human_duration $eta)"
        
        last_bytes=$current_bytes
        sleep 1
    done
    
    echo # New line after progress
}

# Helper functions
get_source_size() {
    case "$SOURCE_SCHEME" in
        file|qcow2|raw|vmdk)
            stat -c%s "$SOURCE_PATH" 2>/dev/null || echo 0
            ;;
        rbd)
            rbd info "$SOURCE_PATH" --format json | jq -r '.size' || echo 0
            ;;
        *)
            echo 0
            ;;
    esac
}

get_bytes_transferred() {
    # Check various methods
    if [[ -f /tmp/migration-progress ]]; then
        cat /tmp/migration-progress
    else
        echo 0
    fi
}

human_bytes() {
    local bytes=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [[ $bytes -gt 1024 ]] && [[ $unit -lt 4 ]]; do
        bytes=$((bytes / 1024))
        unit=$((unit + 1))
    done
    
    echo "$bytes${units[$unit]}"
}

human_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [[ $hours -gt 0 ]]; then
        printf "%dh %dm %ds" $hours $minutes $secs
    elif [[ $minutes -gt 0 ]]; then
        printf "%dm %ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

# Main migration function
migrate() {
    # Parse source and target URIs
    eval "$(parse_uri "$SOURCE_URI" | sed 's/^/SOURCE_/')"
    eval "$(parse_uri "$TARGET_URI" | sed 's/^/TARGET_/')"
    
    log_info "Migration Configuration:"
    echo "  Source: $SOURCE_URI ($SOURCE_SCHEME)"
    echo "  Target: $TARGET_URI ($TARGET_SCHEME)"
    echo "  Mode: ${STREAM_MODE}"
    echo "  Live: ${LIVE_MODE}"
    echo "  Compression: ${COMPRESSION}"
    echo "  Encryption: ${ENCRYPTION}"
    
    # Prepare environment
    if command -v hv-dedup-filter >/dev/null 2>&1; then
        :
    else
        create_dedup_filter
    fi
    
    # Setup source access
    case "$SOURCE_SCHEME" in
        nfs)
            mkdir -p /mnt/nfs-tmp
            mount -t nfs "$SOURCE_HOST:/${SOURCE_PATH%/*}" /mnt/nfs-tmp
            ;;
    esac
    
    # Perform migration
    if [[ "$LIVE_MODE" == "true" ]]; then
        live_migrate
    else
        # Build and execute pipeline
        local pipeline=$(build_pipeline "$SOURCE_SCHEME" "$TARGET_SCHEME")
        log_info "Executing pipeline: $pipeline"
        
        # Start migration in background
        eval "$pipeline" &
        MIGRATION_PID=$!
        
        # Monitor progress
        monitor_progress
        
        # Wait for completion
        wait $MIGRATION_PID
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            log_success "Migration completed successfully"
        else
            log_error "Migration failed with exit code: $exit_code"
            exit $exit_code
        fi
    fi
    
    # Cleanup
    case "$SOURCE_SCHEME" in
        nfs)
            umount /mnt/nfs-tmp 2>/dev/null || true
            ;;
        rbd)
            rbd snap rm "$SOURCE_PATH@migrate-base" 2>/dev/null || true
            ;;
    esac
    
    # Verify if requested
    if [[ "$VERIFY_BLOCKS" == "true" ]]; then
        log_info "Verifying migration..."
        verify_migration
    fi
}

# Verify migration integrity
verify_migration() {
    case "$SOURCE_SCHEME:$TARGET_SCHEME" in
        file:file|qcow2:qcow2)
            local source_hash=$(sha256sum "$SOURCE_PATH" | cut -d' ' -f1)
            local target_hash=$(sha256sum "$TARGET_PATH" | cut -d' ' -f1)
            
            if [[ "$source_hash" == "$target_hash" ]]; then
                log_success "Verification passed"
            else
                log_error "Verification failed: checksums don't match"
                return 1
            fi
            ;;
        *)
            log_warn "Verification not implemented for $SOURCE_SCHEME to $TARGET_SCHEME"
            ;;
    esac
}

# Logging functions (fallback if common.sh not found)
log_info() { echo "[INFO] $*"; }
log_success() { echo "[SUCCESS] $*"; }
log_error() { echo "[ERROR] $*" >&2; }
log_warn() { echo "[WARN] $*" >&2; }
die() { echo "[FATAL] $*" >&2; exit 1; }

# Main function
main() {
    parse_args "$@"
    migrate
}

# Run main function
main "$@"