#!/usr/bin/env bash
#
# Hyper-NixOS Smart Sync - Intelligent File Synchronization
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# This script intelligently syncs the hypervisor installation by:
# 1. Comparing local files with the GitHub repository
# 2. Only downloading files that have changed
# 3. Validating file integrity with checksums
# 4. Falling back to full download if needed
#
# This significantly speeds up development by avoiding full clones
# and reduces bandwidth usage.
#
set -Eeuo pipefail
IFS=$'\n\t'
umask 077
PATH="$HOME/.nix-profile/bin:/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Configuration
GITHUB_REPO="MasterofNull/Hyper-NixOS"
DEFAULT_BRANCH="main"
GITHUB_API="https://api.github.com"
GITHUB_RAW="https://raw.githubusercontent.com"
LOCAL_ROOT="/etc/hypervisor/src"
CACHE_DIR="/var/lib/hypervisor/cache"
STATE_FILE="$CACHE_DIR/sync-state.json"
TEMP_DIR=$(mktemp -d -t hypervisor-sync.XXXXXX)

# Options
REF="${REF:-$DEFAULT_BRANCH}"
FORCE_FULL=false
DRY_RUN=false
VERBOSE=false
CHECK_ONLY=false
SKIP_VALIDATION=false

# Counters
CHECKED=0
CHANGED=0
DOWNLOADED=0
SKIPPED=0
ERRORS=0

cleanup() {
  local ec=$?
  [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
  exit "$ec"
}
trap cleanup EXIT HUP INT TERM

msg() { printf "[smart-sync] %s\n" "$*"; }
verbose() { $VERBOSE && printf "[smart-sync] %s\n" "$*" || true; }
error() { printf "[smart-sync ERROR] %s\n" "$*" >&2; ((ERRORS++)); }

usage() {
  cat <<USAGE
Usage: $(basename "$0") [OPTIONS]

Intelligently sync Hyper-NixOS files from GitHub, downloading only what changed.

Options:
  --ref BRANCH|TAG|SHA    Sync to specific branch/tag/commit (default: $DEFAULT_BRANCH)
  --force-full            Force full download (don't use smart sync)
  --dry-run              Show what would be done without making changes
  --check-only           Only check for changes, don't download
  --skip-validation      Skip checksum validation (faster but less safe)
  --verbose              Show detailed progress
  -h, --help             Show this help

Examples:
  $(basename "$0")                    # Smart sync from main branch
  $(basename "$0") --ref v2.1         # Sync to specific tag
  $(basename "$0") --check-only       # Check what needs updating
  $(basename "$0") --dry-run          # Preview what would be downloaded

Benefits:
  • Only downloads changed files (saves bandwidth)
  • Validates file integrity with checksums
  • 10-50x faster than full git clone for updates
  • Perfect for rapid development iterations

USAGE
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref) REF="$2"; shift 2;;
    --force-full) FORCE_FULL=true; shift;;
    --dry-run) DRY_RUN=true; shift;;
    --check-only) CHECK_ONLY=true; shift;;
    --skip-validation) SKIP_VALIDATION=true; shift;;
    --verbose) VERBOSE=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage; exit 1;;
  esac
done

# Check for required commands
require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Required command not found: $1"
    error "Please install $1 to use smart sync"
    return 1
  fi
}

require_command curl || exit 1
require_command jq || {
  msg "jq not found, installing..."
  
  # Try multiple installation methods
  if command -v nix-env >/dev/null 2>&1; then
    # NixOS user installation
    nix-env -iA nixos.jq
    export PATH="$HOME/.nix-profile/bin:$PATH"
  elif command -v nix >/dev/null 2>&1; then
    # Try nix profile install (new style)
    nix profile install nixpkgs#jq || nix-env -iA nixpkgs.jq || true
    export PATH="$HOME/.nix-profile/bin:$PATH"
  elif command -v apt-get >/dev/null 2>&1; then
    # Debian/Ubuntu systems
    msg "Installing jq via apt-get..."
    apt-get update -qq && apt-get install -y -qq jq
  elif command -v yum >/dev/null 2>&1; then
    # RHEL/CentOS systems
    msg "Installing jq via yum..."
    yum install -y -q jq
  elif command -v apk >/dev/null 2>&1; then
    # Alpine Linux
    msg "Installing jq via apk..."
    apk add --quiet jq
  else
    error "Cannot install jq automatically"
    error "Please install jq manually:"
    error "  - NixOS: nix-env -iA nixpkgs.jq"
    error "  - Debian/Ubuntu: apt-get install jq"
    error "  - RHEL/CentOS: yum install jq"
    error "  - macOS: brew install jq"
    exit 1
  fi
  
  # Verify jq is now available
  if ! command -v jq >/dev/null 2>&1; then
    error "jq installation appeared to succeed but jq is still not available in PATH"
    error "Please install jq manually and try again"
    exit 1
  fi
  msg "jq installed and available"
}

# Get GitHub API token if available (increases rate limits)
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
if [[ -z "$GITHUB_TOKEN" ]] && [[ -f ~/.config/github/token ]]; then
  GITHUB_TOKEN=$(cat ~/.config/github/token)
fi

# Build curl command with optional auth
github_api_curl() {
  local url="$1"
  local args=(-s -f)
  if [[ -n "$GITHUB_TOKEN" ]]; then
    args+=(-H "Authorization: token $GITHUB_TOKEN")
  fi
  curl "${args[@]}" "$url"
}

# Get the commit SHA for the specified ref
get_commit_sha() {
  local ref="$1"
  verbose "Resolving ref '$ref' to commit SHA..."
  
  # Try as branch first
  local sha
  sha=$(github_api_curl "$GITHUB_API/repos/$GITHUB_REPO/git/refs/heads/$ref" 2>/dev/null | jq -r '.object.sha' 2>/dev/null || true)
  
  # Try as tag if branch failed
  if [[ -z "$sha" || "$sha" == "null" ]]; then
    sha=$(github_api_curl "$GITHUB_API/repos/$GITHUB_REPO/git/refs/tags/$ref" 2>/dev/null | jq -r '.object.sha' 2>/dev/null || true)
  fi
  
  # Try as direct commit SHA
  if [[ -z "$sha" || "$sha" == "null" ]]; then
    sha=$(github_api_curl "$GITHUB_API/repos/$GITHUB_REPO/commits/$ref" 2>/dev/null | jq -r '.sha' 2>/dev/null || true)
  fi
  
  if [[ -z "$sha" || "$sha" == "null" ]]; then
    error "Could not resolve ref '$ref' to a commit SHA"
    return 1
  fi
  
  verbose "Resolved '$ref' to commit: $sha"
  echo "$sha"
}

# Get file tree from GitHub
get_remote_tree() {
  local commit_sha="$1"
  verbose "Fetching file tree from GitHub..."
  
  local tree_url="$GITHUB_API/repos/$GITHUB_REPO/git/trees/$commit_sha?recursive=1"
  github_api_curl "$tree_url" | jq -r '.tree[] | select(.type == "blob") | "\(.path)|\(.sha)|\(.size)"' || {
    error "Failed to fetch file tree from GitHub"
    return 1
  }
}

# Calculate local file SHA1 (GitHub uses SHA1 for blob hashes)
calculate_file_sha() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo ""
    return
  fi
  
  # GitHub calculates blob SHA as: sha1("blob <size>\0<content>")
  local size
  size=$(wc -c < "$file")
  {
    printf "blob %d\0" "$size"
    cat "$file"
  } | sha1sum | awk '{print $1}'
}

# Compare local and remote files
# Note: This function skips files that system_installer.sh excludes during installation
# to prevent false positives when comparing after a fresh install.
# Excluded paths: .git/, result/, target/, tools/target/, var/, *.socket
compare_files() {
  local remote_tree_file="$1"
  local changed_files="$TEMP_DIR/changed_files.txt"
  local summary="$TEMP_DIR/summary.json"
  
  msg "Comparing local files with remote repository..."
  
  > "$changed_files"
  
  local total=0
  local changed=0
  local unchanged=0
  local missing_local=0
  
  while IFS='|' read -r path remote_sha size; do
    ((total++))
    ((CHECKED++))
    
    local local_file="$LOCAL_ROOT/$path"
    
    verbose "Checking: $path"
    
    # Skip files that bootstrap excludes (build artifacts, git metadata, etc.)
    # These paths match the exclusions in system_installer.sh copy_repo_to_etc function
    if [[ "$path" == .git/* ]] || \
       [[ "$path" == result/* ]] || \
       [[ "$path" == target/* ]] || \
       [[ "$path" == tools/target/* ]] || \
       [[ "$path" == var/* ]] || \
       [[ "$path" == *.socket ]]; then
      ((SKIPPED++))
      continue
    fi
    
    if [[ ! -f "$local_file" ]]; then
      verbose "  → Missing locally"
      echo "$path|$remote_sha|$size|missing" >> "$changed_files"
      ((missing_local++))
      ((CHANGED++))
      continue
    fi
    
    # Calculate local SHA
    local local_sha
    if $SKIP_VALIDATION; then
      # Quick size comparison only
      local local_size
      local_size=$(stat -c%s "$local_file" 2>/dev/null || stat -f%z "$local_file" 2>/dev/null)
      if [[ "$local_size" != "$size" ]]; then
        verbose "  → Size mismatch (local: $local_size, remote: $size)"
        echo "$path|$remote_sha|$size|changed" >> "$changed_files"
        ((changed++))
        ((CHANGED++))
      else
        ((unchanged++))
      fi
    else
      local_sha=$(calculate_file_sha "$local_file")
      
      if [[ "$local_sha" != "$remote_sha" ]]; then
        verbose "  → Changed (SHA mismatch)"
        echo "$path|$remote_sha|$size|changed" >> "$changed_files"
        ((changed++))
        ((CHANGED++))
      else
        verbose "  → Unchanged"
        ((unchanged++))
      fi
    fi
    
    # Progress indicator every 100 files
    if ((total % 100 == 0)); then
      msg "Checked $total files... ($changed changed, $missing_local missing)"
    fi
  done < "$remote_tree_file"
  
  # Save summary
  jq -n \
    --arg total "$total" \
    --arg changed "$changed" \
    --arg missing "$missing_local" \
    --arg unchanged "$unchanged" \
    '{
      total: ($total | tonumber),
      changed: ($changed | tonumber),
      missing: ($missing | tonumber),
      unchanged: ($unchanged | tonumber)
    }' > "$summary"
  
  msg "Comparison complete:"
  msg "  Total files checked: $total"
  msg "  Unchanged: $unchanged"
  msg "  Changed: $changed"
  msg "  Missing locally: $missing_local"
  
  if [[ $changed -eq 0 && $missing_local -eq 0 ]]; then
    msg "✓ All files are up to date!"
    return 1  # Signal no changes needed
  fi
  
  return 0  # Changes found
}

# Download a single file from GitHub
download_file() {
  local path="$1"
  local remote_sha="$2"
  local dest="$LOCAL_ROOT/$path"
  
  verbose "Downloading: $path"
  
  if $DRY_RUN; then
    msg "  [DRY RUN] Would download: $path"
    return 0
  fi
  
  # Create directory if needed
  mkdir -p "$(dirname "$dest")"
  
  # Download from raw GitHub
  local url="$GITHUB_RAW/$GITHUB_REPO/$REF/$path"
  local temp_file="$TEMP_DIR/$(basename "$path")"
  
  if curl -f -s -L -o "$temp_file" "$url"; then
    # Verify SHA if not skipping validation
    if ! $SKIP_VALIDATION; then
      local downloaded_sha
      downloaded_sha=$(calculate_file_sha "$temp_file")
      if [[ "$downloaded_sha" != "$remote_sha" ]]; then
        error "SHA mismatch for $path (expected: $remote_sha, got: $downloaded_sha)"
        rm -f "$temp_file"
        return 1
      fi
    fi
    
    # Move to destination
    mv "$temp_file" "$dest"
    chmod 0644 "$dest"
    
    # Make scripts executable
    if [[ "$path" == scripts/* ]] && [[ "$path" == *.sh ]] || [[ "$path" == scripts/* ]] && [[ ! "$path" == *.* ]]; then
      chmod 0755 "$dest"
    fi
    
    ((DOWNLOADED++))
    return 0
  else
    error "Failed to download: $path"
    return 1
  fi
}

# Download all changed files
download_changes() {
  local changed_files="$1"
  
  if [[ ! -f "$changed_files" ]] || [[ ! -s "$changed_files" ]]; then
    msg "No files to download"
    return 0
  fi
  
  local total
  total=$(wc -l < "$changed_files")
  msg "Downloading $total changed files..."
  
  local current=0
  local failed=0
  
  while IFS='|' read -r path remote_sha size status; do
    ((current++))
    
    if ((current % 10 == 0)) || [[ $current -eq $total ]]; then
      msg "Progress: $current/$total files..."
    fi
    
    if ! download_file "$path" "$remote_sha"; then
      ((failed++))
    fi
  done < "$changed_files"
  
  if [[ $failed -gt 0 ]]; then
    error "$failed files failed to download"
    return 1
  fi
  
  msg "✓ Successfully downloaded $total files"
  return 0
}

# Fallback to full git clone
full_clone() {
  msg "Falling back to full git clone..."
  
  if $DRY_RUN; then
    msg "[DRY RUN] Would perform full git clone"
    return 0
  fi
  
  local temp_clone="$TEMP_DIR/full-clone"
  
  msg "Cloning repository (ref: $REF)..."
  if git clone --depth 1 --branch "$REF" "https://github.com/$GITHUB_REPO" "$temp_clone"; then
    msg "Copying files to $LOCAL_ROOT..."
    
    # Backup existing installation
    if [[ -d "$LOCAL_ROOT" ]]; then
      local backup="$LOCAL_ROOT.backup.$(date +%s)"
      msg "Backing up existing installation to $backup"
      mv "$LOCAL_ROOT" "$backup"
    fi
    
    mkdir -p "$LOCAL_ROOT"
    
    # Use same exclusions as system_installer.sh for consistency
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --exclude ".git/" --exclude "result" --exclude "target/" --exclude "tools/target/" --exclude "var/" --exclude "*.socket" "$temp_clone/" "$LOCAL_ROOT/"
    else
      cp -a "$temp_clone"/* "$LOCAL_ROOT/" 2>/dev/null || true
      cp -a "$temp_clone"/.[!.]* "$LOCAL_ROOT/" 2>/dev/null || true
      # Manual cleanup of excluded paths for non-rsync case
      rm -rf "$LOCAL_ROOT/.git" "$LOCAL_ROOT/result" "$LOCAL_ROOT/target" "$LOCAL_ROOT/tools/target" "$LOCAL_ROOT/var" 2>/dev/null || true
      find "$LOCAL_ROOT" -name "*.socket" -delete 2>/dev/null || true
    fi
    
    # Set permissions
    chown -R root:root "$LOCAL_ROOT" || true
    find "$LOCAL_ROOT" -type d -exec chmod 0755 {} + 2>/dev/null || true
    find "$LOCAL_ROOT" -type f -exec chmod 0644 {} + 2>/dev/null || true
    if [[ -d "$LOCAL_ROOT/scripts" ]]; then
      find "$LOCAL_ROOT/scripts" -type f -exec chmod 0755 {} + 2>/dev/null || true
    fi
    
    msg "✓ Full clone completed successfully"
    return 0
  else
    error "Full git clone failed"
    return 1
  fi
}

# Save sync state
save_state() {
  local commit_sha="$1"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  mkdir -p "$CACHE_DIR"
  
  jq -n \
    --arg sha "$commit_sha" \
    --arg ref "$REF" \
    --arg timestamp "$timestamp" \
    --arg checked "$CHECKED" \
    --arg changed "$CHANGED" \
    --arg downloaded "$DOWNLOADED" \
    --arg errors "$ERRORS" \
    '{
      last_sync: {
        commit_sha: $sha,
        ref: $ref,
        timestamp: $timestamp
      },
      stats: {
        checked: ($checked | tonumber),
        changed: ($changed | tonumber),
        downloaded: ($downloaded | tonumber),
        errors: ($errors | tonumber)
      }
    }' > "$STATE_FILE"
  
  verbose "Saved sync state to $STATE_FILE"
}

# Main sync logic
main() {
  msg "Hyper-NixOS Smart Sync"
  msg "Repository: $GITHUB_REPO"
  msg "Reference: $REF"
  msg "Local root: $LOCAL_ROOT"
  
  if $DRY_RUN; then
    msg "DRY RUN MODE - No changes will be made"
  fi
  
  if $CHECK_ONLY; then
    msg "CHECK ONLY MODE - Will not download files"
  fi
  
  # Ensure cache directory exists
  mkdir -p "$CACHE_DIR"
  
  # Get commit SHA for ref
  local commit_sha
  if ! commit_sha=$(get_commit_sha "$REF"); then
    error "Failed to resolve reference"
    exit 1
  fi
  
  # Check if we should force full download
  if $FORCE_FULL; then
    msg "Force full download requested"
    full_clone
    save_state "$commit_sha"
    exit $?
  fi
  
  # Check if local root exists
  if [[ ! -d "$LOCAL_ROOT" ]]; then
    msg "Local installation not found at $LOCAL_ROOT"
    msg "Performing initial full clone..."
    full_clone
    save_state "$commit_sha"
    exit $?
  fi
  
  # Get remote file tree
  local tree_file="$TEMP_DIR/remote_tree.txt"
  if ! get_remote_tree "$commit_sha" > "$tree_file"; then
    error "Failed to fetch remote file tree"
    msg "Falling back to full clone..."
    full_clone
    save_state "$commit_sha"
    exit $?
  fi
  
  # Compare files
  if ! compare_files "$tree_file"; then
    msg "No changes detected - system is up to date!"
    save_state "$commit_sha"
    exit 0
  fi
  
  # Show what would be done
  if $CHECK_ONLY; then
    msg "Check complete. Files need updating: $CHANGED"
    msg "Run without --check-only to download changes"
    exit 0
  fi
  
  # Download changes
  local changed_list="$TEMP_DIR/changed_files.txt"
  if [[ -f "$changed_list" ]]; then
    if ! download_changes "$changed_list"; then
      error "Failed to download some files"
      msg "Consider running with --force-full for complete sync"
      exit 1
    fi
  fi
  
  # Save state
  save_state "$commit_sha"
  
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  msg "✓ Smart sync completed successfully!"
  msg "  Files checked: $CHECKED"
  msg "  Files changed: $CHANGED"
  msg "  Files downloaded: $DOWNLOADED"
  msg "  Errors: $ERRORS"
  msg "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  if [[ $ERRORS -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
