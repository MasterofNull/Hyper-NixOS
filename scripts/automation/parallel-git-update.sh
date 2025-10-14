#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
# Parallel git repository updater

source "$(dirname "$0")/parallel-framework.sh"

# Repository list file
REPO_FILE="${1:-repos.txt}"

if [[ ! -f "$REPO_FILE" ]]; then
    echo "Creating example repos.txt file..."
    cat > repos.txt << 'EOL'
https://github.com/docker/docker-bench-security|/opt/tools/docker-bench
https://github.com/aquasecurity/trivy|/opt/tools/trivy
https://github.com/projectdiscovery/nuclei|/opt/tools/nuclei
EOL
fi

# Read repositories and create update tasks
tasks=()
while IFS='|' read -r url path; do
    [[ -z "$url" ]] && continue
    tasks+=("git_smart_update '$url' '$path' 0")
done < "$REPO_FILE"

echo "Updating ${#tasks[@]} repositories in parallel..."
parallel_execute tasks 5

echo "Repository updates complete!"
