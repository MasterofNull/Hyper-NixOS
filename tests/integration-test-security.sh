#!/usr/bin/env bash
# Integration tests for security implementations

source "$(dirname "$0")/../scripts/automation/parallel-framework.sh"

FAILED_TESTS=0
PASSED_TESTS=0

# Test function
test_feature() {
    local name="$1"
    local command="$2"
    
    echo -n "Testing $name... "
    
    if eval "$command" &> /dev/null; then
        echo -e "\033[0;32mPASS\033[0m"
        ((PASSED_TESTS++))
    else
        echo -e "\033[0;31mFAIL\033[0m"
        ((FAILED_TESTS++))
    fi
}

echo "Running integration tests..."

# Test SSH monitoring
test_feature "SSH monitoring script" "test -f scripts/security/ssh-monitor.sh"

# Test Docker security
test_feature "Docker security policy" "test -f configs/docker/security-policy.json"
test_feature "Docker safe wrapper" "command -v docker-safe"

# Test parallel framework
test_feature "Parallel framework" "source scripts/automation/parallel-framework.sh && type parallel_execute"

# Test monitoring
test_feature "Prometheus rules" "test -f monitoring/rules/security-enhanced.yml"
test_feature "Grafana dashboard" "test -f monitoring/dashboards/security-overview.json"

# Test automation
test_feature "Notification system" "test -x scripts/automation/notify.sh"
test_feature "Security scanner" "test -x scripts/security/automated-security-scan.sh"

echo
echo "Test Results:"
echo "  Passed: $PASSED_TESTS"
echo "  Failed: $FAILED_TESTS"

exit $FAILED_TESTS
