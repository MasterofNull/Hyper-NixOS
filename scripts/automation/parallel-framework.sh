#!/usr/bin/env bash
# Advanced Parallel Execution Framework
# Implements patterns discovered from security distribution analysis

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly MAX_PARALLEL_JOBS=${MAX_PARALLEL_JOBS:-5}
readonly LOG_DIR="${LOG_DIR:-/tmp/parallel-logs}"
readonly PROGRESS_UPDATE_INTERVAL=1

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Job tracking arrays
declare -A job_pids
declare -A job_names
declare -A job_start_times
declare -A job_statuses

# Statistics
total_jobs=0
completed_jobs=0
failed_jobs=0

# Parallel execution with progress tracking
parallel_execute() {
    local -n tasks=$1
    local max_jobs=${2:-$MAX_PARALLEL_JOBS}
    local job_timeout=${3:-0}  # 0 means no timeout
    
    echo -e "${BLUE}Starting parallel execution with max $max_jobs concurrent jobs${NC}"
    
    local job_id=0
    for task in "${tasks[@]}"; do
        # Wait if we've reached max parallel jobs
        while [[ $(jobs -r | wc -l) -ge $max_jobs ]]; do
            check_completed_jobs
            sleep 0.1
        done
        
        # Start new job
        ((job_id++))
        ((total_jobs++))
        
        start_job "$job_id" "$task" "$job_timeout"
    done
    
    # Wait for all remaining jobs
    echo -e "${YELLOW}Waiting for remaining jobs to complete...${NC}"
    while [[ ${#job_pids[@]} -gt 0 ]]; do
        check_completed_jobs
        show_progress
        sleep $PROGRESS_UPDATE_INTERVAL
    done
    
    show_final_summary
}

# Start a single job
start_job() {
    local job_id=$1
    local task=$2
    local timeout=$3
    
    local job_name=$(echo "$task" | awk '{print $1}')
    local log_file="$LOG_DIR/job_${job_id}_$(date +%Y%m%d_%H%M%S).log"
    
    echo -e "${BLUE}[$(date +%H:%M:%S)] Starting job $job_id: $job_name${NC}"
    
    # Execute job with timeout if specified
    if [[ $timeout -gt 0 ]]; then
        timeout --preserve-status "$timeout" bash -c "$task" > "$log_file" 2>&1 &
    else
        bash -c "$task" > "$log_file" 2>&1 &
    fi
    
    local pid=$!
    
    # Track job information
    job_pids[$job_id]=$pid
    job_names[$job_id]=$job_name
    job_start_times[$job_id]=$(date +%s)
    job_statuses[$job_id]="RUNNING"
}

# Check for completed jobs
check_completed_jobs() {
    for job_id in "${!job_pids[@]}"; do
        local pid=${job_pids[$job_id]}
        
        if ! kill -0 "$pid" 2>/dev/null; then
            # Job completed
            wait "$pid"
            local exit_code=$?
            
            handle_job_completion "$job_id" "$exit_code"
            
            # Remove from tracking
            unset job_pids[$job_id]
        fi
    done
}

# Handle job completion
handle_job_completion() {
    local job_id=$1
    local exit_code=$2
    
    local job_name=${job_names[$job_id]}
    local start_time=${job_start_times[$job_id]}
    local duration=$(($(date +%s) - start_time))
    
    ((completed_jobs++))
    
    if [[ $exit_code -eq 0 ]]; then
        job_statuses[$job_id]="SUCCESS"
        echo -e "${GREEN}[$(date +%H:%M:%S)] ✓ Completed job $job_id: $job_name (${duration}s)${NC}"
    else
        ((failed_jobs++))
        job_statuses[$job_id]="FAILED"
        echo -e "${RED}[$(date +%H:%M:%S)] ✗ Failed job $job_id: $job_name (exit: $exit_code, ${duration}s)${NC}"
        
        # Show last few lines of error log
        local log_file="$LOG_DIR/job_${job_id}_*.log"
        if [[ -f $log_file ]]; then
            echo -e "${RED}Last 5 lines of error log:${NC}"
            tail -5 $log_file | sed 's/^/  /'
        fi
    fi
}

# Show progress
show_progress() {
    local running_jobs=${#job_pids[@]}
    local progress_pct=$((completed_jobs * 100 / total_jobs))
    
    printf "\r${YELLOW}Progress: [%-20s] %d%% | Running: %d | Completed: %d/%d | Failed: %d${NC}" \
        "$(printf '#%.0s' $(seq 1 $((progress_pct / 5))))" \
        "$progress_pct" \
        "$running_jobs" \
        "$completed_jobs" \
        "$total_jobs" \
        "$failed_jobs"
}

# Show final summary
show_final_summary() {
    echo -e "\n\n${BLUE}=== Execution Summary ===${NC}"
    echo -e "Total jobs: $total_jobs"
    echo -e "Successful: ${GREEN}$((completed_jobs - failed_jobs))${NC}"
    echo -e "Failed: ${RED}$failed_jobs${NC}"
    
    if [[ $failed_jobs -gt 0 ]]; then
        echo -e "\n${RED}Failed jobs:${NC}"
        for job_id in "${!job_statuses[@]}"; do
            if [[ ${job_statuses[$job_id]} == "FAILED" ]]; then
                echo -e "  - Job $job_id: ${job_names[$job_id]}"
            fi
        done
    fi
    
    echo -e "\n${BLUE}Logs available in: $LOG_DIR${NC}"
}

# Parallel map function (similar to GNU parallel)
parallel_map() {
    local command=$1
    shift
    local items=("$@")
    
    local tasks=()
    for item in "${items[@]}"; do
        tasks+=("$command $item")
    done
    
    parallel_execute tasks
}

# Batch processing with chunking
parallel_batch() {
    local command=$1
    local batch_size=$2
    shift 2
    local items=("$@")
    
    local tasks=()
    local batch=()
    
    for item in "${items[@]}"; do
        batch+=("$item")
        
        if [[ ${#batch[@]} -eq $batch_size ]]; then
            local batch_str="${batch[*]}"
            tasks+=("$command '$batch_str'")
            batch=()
        fi
    done
    
    # Process remaining items
    if [[ ${#batch[@]} -gt 0 ]]; then
        local batch_str="${batch[*]}"
        tasks+=("$command '$batch_str'")
    fi
    
    parallel_execute tasks
}

# Example usage functions
example_scan_targets() {
    echo "Example: Parallel network scanning"
    
    local targets=("192.168.1.1" "192.168.1.100" "192.168.1.200" "10.0.0.1")
    local scan_tasks=()
    
    for target in "${targets[@]}"; do
        scan_tasks+=("nmap -sV -sC -oA $LOG_DIR/scan_$target $target")
    done
    
    parallel_execute scan_tasks 3  # Max 3 concurrent scans
}

example_process_files() {
    echo "Example: Parallel file processing"
    
    # Process all log files in parallel
    parallel_map "gzip -9" /var/log/*.log
}

example_git_updates() {
    echo "Example: Parallel git repository updates"
    
    local repos=(
        "https://github.com/user/repo1|/opt/repos/repo1"
        "https://github.com/user/repo2|/opt/repos/repo2"
        "https://github.com/user/repo3|/opt/repos/repo3"
    )
    
    local update_tasks=()
    for repo in "${repos[@]}"; do
        IFS='|' read -r url path <<< "$repo"
        update_tasks+=("git_smart_update '$url' '$path'")
    done
    
    parallel_execute update_tasks
}

# Git smart update function (from discovered patterns)
git_smart_update() {
    local url=$1
    local path=$2
    local force=${3:-0}
    
    # Check if recently updated (within 24 hours)
    if [[ -d "$path/.git" ]] && [[ $force -eq 0 ]]; then
        local last_fetch=$(stat -c %Y "$path/.git/FETCH_HEAD" 2>/dev/null || echo 0)
        local current_time=$(date +%s)
        local time_diff=$((current_time - last_fetch))
        
        if [[ $time_diff -lt 86400 ]]; then
            echo "[$path] Recently updated, skipping..."
            return 0
        fi
    fi
    
    # Clone or update
    if [[ ! -d "$path" ]]; then
        echo "[$path] Cloning..."
        git clone --depth 1 "$url" "$path"
    else
        echo "[$path] Updating..."
        cd "$path" && git fetch --depth 1 && git reset --hard origin/$(git symbolic-ref --short HEAD)
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-help}" in
        scan)
            example_scan_targets
            ;;
        files)
            example_process_files
            ;;
        git)
            example_git_updates
            ;;
        help|*)
            echo "Usage: $0 {scan|files|git|help}"
            echo
            echo "This script provides parallel execution capabilities:"
            echo "  scan  - Example parallel network scanning"
            echo "  files - Example parallel file processing"
            echo "  git   - Example parallel git updates"
            echo
            echo "To use in your own scripts:"
            echo "  source $0"
            echo "  tasks=(\"command1\" \"command2\" \"command3\")"
            echo "  parallel_execute tasks"
            ;;
    esac
fi