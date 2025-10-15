#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154,SC1091
#
# Hyper-NixOS Security Audit
# Copyright (C) 2024-2025 MasterofNull
# Licensed under GPL v3.0
#
# Comprehensive security audit of new features
# Checks for common vulnerabilities and misconfigurations
#

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/ui.sh"

# Initialize script
init_script "$(basename "$0")"

set -euo pipefail
PATH="/run/current-system/sw/bin:/usr/sbin:/usr/bin:/sbin:/bin"

AUDIT_LOG="/var/lib/hypervisor/logs/security-audit-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$(dirname "$AUDIT_LOG")"

# Colors

ISSUES_FOUND=0
WARNINGS_FOUND=0

log() {
  echo "[$(date -Iseconds)] $*" | tee -a "$AUDIT_LOG"
}

check_pass() {
  echo -e "  ${GREEN}✓${NC} $1"
  log "PASS: $1"
}

check_fail() {
  echo -e "  ${RED}✗${NC} $1"
  log "FAIL: $1"
  ((ISSUES_FOUND++))
}

check_warn() {
  echo -e "  ${YELLOW}⚠${NC} $1"
  log "WARN: $1"
  ((WARNINGS_FOUND++))
}

section() {
  echo ""
  echo -e "${BOLD}${BLUE}═══ $1 ═══${NC}"
  log "=== $1 ==="
}

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║          SECURITY AUDIT - NEW FEATURES                        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
log "Security audit started"

#==============================================================================
# 1. WEB DASHBOARD SECURITY
#==============================================================================
section "1. Web Dashboard Security"

# Check Flask is not running in debug mode
if [[ -f /etc/hypervisor/scripts/web_dashboard.py ]]; then
  echo -n "Checking Flask debug mode... "
  if grep -q "debug=False" /etc/hypervisor/scripts/web_dashboard.py; then
    check_pass "Flask debug mode disabled (production safe)"
  else
    check_fail "Flask debug mode might be enabled (security risk)"
  fi
  
  # Check Flask binds to localhost only
  echo -n "Checking Flask bind address... "
  if grep -q "host='127.0.0.1'" /etc/hypervisor/scripts/web_dashboard.py; then
    check_pass "Flask binds to localhost only (safe)"
  else
    check_warn "Flask may bind to 0.0.0.0 (external access without auth)"
  fi
  
  # Check for authentication
  echo -n "Checking authentication... "
  if grep -q "@auth.login_required\|@requires_auth\|basicAuth" /etc/hypervisor/scripts/web_dashboard.py web/templates/*.html 2>/dev/null; then
    check_pass "Authentication implemented"
  else
    check_warn "No authentication found - dashboard accessible to localhost users"
    echo "     NOTE: This is acceptable if only accessed via localhost"
    echo "     For external access, use nginx reverse proxy with authentication"
  fi
  
  # Check for SQL injection protection
  echo -n "Checking for SQL queries... "
  if grep -iE "SELECT|INSERT|UPDATE|DELETE.*FROM" /etc/hypervisor/scripts/web_dashboard.py 2>/dev/null; then
    check_warn "SQL queries found - verify parameterization"
  else
    check_pass "No SQL queries (using subprocess/virsh only)"
  fi
  
  # Check for command injection protection
  echo -n "Checking command injection protection... "
  if grep -E "shell=True.*\{|format.*shell=True" /etc/hypervisor/scripts/web_dashboard.py 2>/dev/null; then
    check_warn "Potential command injection - verify input sanitization"
  else
    check_pass "Commands use safe subprocess methods"
  fi
  
  # Check systemd service isolation
  if [[ -f /etc/systemd/system/hypervisor-web-dashboard.service ]] || \
     grep -q "hypervisor-web-dashboard" modules/web/dashboard.nix 2>/dev/null; then
    echo -n "Checking systemd isolation... "
    if grep -q "ProtectSystem=strict\|ReadWritePaths" modules/web/dashboard.nix 2>/dev/null; then
      check_pass "Systemd service properly isolated"
    else
      check_warn "Systemd isolation not configured"
    fi
  fi
else
  check_pass "Web dashboard not installed (optional feature)"
fi

#==============================================================================
# 2. ALERT SYSTEM SECURITY
#==============================================================================
section "2. Alert System Security"

if [[ -f /etc/hypervisor/scripts/alert_manager.sh ]]; then
  # Check for hardcoded credentials
  echo -n "Checking for hardcoded credentials... "
  if grep -iE "password=|smtp_pass=\"[^$]|api_key=\"[^$]" /etc/hypervisor/scripts/alert_manager.sh 2>/dev/null; then
    check_fail "Hardcoded credentials found in alert_manager.sh"
  else
    check_pass "No hardcoded credentials"
  fi
  
  # Check configuration file permissions
  if [[ -f /var/lib/hypervisor/configuration/alerts.conf ]]; then
    echo -n "Checking alert config permissions... "
    local perms=$(stat -c %a /var/lib/hypervisor/configuration/alerts.conf 2>/dev/null)
    if [[ "$perms" =~ ^[0-7]00$ ]]; then
      check_pass "Alert config has restrictive permissions ($perms)"
    else
      check_warn "Alert config readable by others ($perms) - may contain SMTP passwords"
    fi
  fi
  
  # Check for webhook URL exposure
  echo -n "Checking webhook URL security... "
  if grep -q "WEBHOOK_URL=" modules/monitoring/alerting.nix 2>/dev/null; then
    if grep -q "WEBHOOK_URL=\"https" modules/monitoring/alerting.nix; then
      check_pass "Webhooks use HTTPS"
    else
      check_warn "Webhooks may use HTTP (unencrypted)"
    fi
  fi
  
  # Check log file permissions
  if [[ -f /var/lib/hypervisor/logs/alerts.log ]]; then
    echo -n "Checking alert log permissions... "
    local perms=$(stat -c %a /var/lib/hypervisor/logs/alerts.log 2>/dev/null)
    if [[ "$perms" =~ ^[0-7][0-7]0$ ]]; then
      check_pass "Alert logs not world-readable"
    else
      check_warn "Alert logs world-readable - may contain sensitive info"
    fi
  fi
else
  check_pass "Alert system not active (optional feature)"
fi

#==============================================================================
# 3. TEST FRAMEWORK SECURITY
#==============================================================================
section "3. Test Framework Security"

if [[ -d /etc/hypervisor/tests ]]; then
  # Check test scripts don't run as root unnecessarily
  echo -n "Checking test script permissions... "
  local root_tests=$(grep -r "sudo\|EUID.*0" tests/ 2>/dev/null | wc -l)
  if [[ $root_tests -gt 5 ]]; then
    check_warn "Many tests require root - verify necessity"
  else
    check_pass "Tests use minimal privileges"
  fi
  
  # Check for test data cleanup
  echo -n "Checking test cleanup... "
  if grep -r "trap.*cleanup\|rm.*TEST_DIR" tests/ 2>/dev/null | grep -q cleanup; then
    check_pass "Tests clean up after themselves"
  else
    check_warn "Some tests may not clean up temporary files"
  fi
  
  # Check tests don't modify production data
  echo -n "Checking production data protection... "
  if grep -r "/var/lib/hypervisor/vm_profiles/\|rm -rf /etc/hypervisor" tests/ 2>/dev/null; then
    check_fail "Tests may modify production data!"
  else
    check_pass "Tests use temporary locations"
  fi
  
  # Check CI pipeline doesn't expose secrets
  if [[ -f .github/workflows/test.yml ]]; then
    echo -n "Checking CI secrets exposure... "
    if grep -iE "password|secret|token" .github/workflows/test.yml 2>/dev/null | grep -v "uses: actions"; then
      check_warn "Potential secrets in CI config"
    else
      check_pass "No secrets in CI pipeline"
    fi
  fi
else
  check_pass "Test framework not present"
fi

#==============================================================================
# 4. BACKUP VERIFICATION SECURITY
#==============================================================================
section "4. Backup Verification Security"

if [[ -f /etc/hypervisor/scripts/automated_backup_verification.sh ]]; then
  # Check temporary directories are secure
  echo -n "Checking temp directory security... "
  if grep -q "mktemp.*0700\|umask 077" /etc/hypervisor/scripts/automated_backup_verification.sh /etc/hypervisor/scripts/guided_backup_verification.sh 2>/dev/null; then
    check_pass "Temporary directories use secure permissions"
  else
    check_warn "Verify temp directories are created securely"
  fi
  
  # Check backup files aren't exposed
  echo -n "Checking backup directory permissions... "
  if [[ -d /var/lib/hypervisor/backups ]]; then
    local perms=$(stat -c %a /var/lib/hypervisor/backups 2>/dev/null)
    if [[ "$perms" =~ ^7[0-7]0$ ]]; then
      check_pass "Backup directory has restrictive permissions"
    else
      check_warn "Backup directory may be too permissive ($perms)"
    fi
  fi
  
  # Check verification doesn't modify originals
  echo -n "Checking backup modification protection... "
  if grep -q "readonly\|cp.*backup.*test" /etc/hypervisor/scripts/automated_backup_verification.sh 2>/dev/null; then
    check_pass "Verification uses copies, not originals"
  else
    check_warn "Verify backups aren't modified during verification"
  fi
fi

#==============================================================================
# 5. METRICS COLLECTION SECURITY
#==============================================================================
section "5. Metrics Collection Security"

# Check metrics don't expose sensitive data
echo -n "Checking metrics for sensitive data... "
if grep -iE "password|secret|private.*key" /var/lib/hypervisor/metrics*.json 2>/dev/null; then
  check_fail "Sensitive data in metrics files!"
else
  check_pass "No sensitive data in metrics"
fi

# Check metrics file permissions
if ls /var/lib/hypervisor/metrics*.json >/dev/null 2>&1; then
  echo -n "Checking metrics file permissions... "
  local bad_perms=$(find /var/lib/hypervisor -name "metrics*.json" -perm /044 2>/dev/null | wc -l)
  if [[ $bad_perms -eq 0 ]]; then
    check_pass "Metrics files not world-readable"
  else
    check_warn "$bad_perms metrics files are world-readable"
  fi
fi

#==============================================================================
# 6. FILE PERMISSION AUDIT
#==============================================================================
section "6. File Permissions"

# Check script permissions
echo -n "Checking new script permissions... "
local world_writable=$(find scripts/ -type f -name "*.sh" -perm /022 2>/dev/null | wc -l)
if [[ $world_writable -eq 0 ]]; then
  check_pass "No world-writable scripts"
else
  check_fail "$world_writable scripts are world-writable (security risk)"
fi

# Check for setuid/setgid
echo -n "Checking for setuid/setgid files... "
local setuid_files=$(find scripts/ modules/ -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | wc -l)
if [[ $setuid_files -eq 0 ]]; then
  check_pass "No setuid/setgid files"
else
  check_warn "$setuid_files setuid/setgid files found"
fi

#==============================================================================
# 7. INPUT VALIDATION
#==============================================================================
section "7. Input Validation"

# Check for unvalidated user input
echo -n "Checking input validation in Python... "
if [[ -f scripts/web_dashboard.py ]]; then
  if grep -E "request\.(args|form|json)\[.*\]" scripts/web_dashboard.py 2>/dev/null | grep -v "get("; then
    check_warn "Direct request parameter access - verify validation"
  else
    check_pass "Input appears to use .get() method (safer)"
  fi
fi

# Check for shell injection in bash scripts
echo -n "Checking shell injection protection... "
local unsafe_evals=$(grep -r "eval.*\$\|eval.*\`" scripts/*.sh 2>/dev/null | grep -v "test_" | wc -l)
if [[ $unsafe_evals -gt 3 ]]; then
  check_warn "$unsafe_evals uses of eval with variables"
else
  check_pass "Minimal use of dangerous shell constructs"
fi

#==============================================================================
# 8. SECRETS AND CREDENTIALS
#==============================================================================
section "8. Secrets Management"

# Check for hardcoded passwords
echo -n "Checking for hardcoded passwords... "
if grep -rE "password=.*['\"][^$]|passwd=.*['\"][^$]|pwd=.*['\"][^$]" \
   scripts/ modules/ --include="*.sh" --include="*.py" --include="*.nix" 2>/dev/null | \
   grep -v "SMTP_PASS=\|example\|placeholder\|your-password"; then
  check_fail "Hardcoded passwords found!"
else
  check_pass "No hardcoded passwords"
fi

# Check for API keys
echo -n "Checking for API keys... "
if grep -rE "api[_-]key=.*['\"][A-Za-z0-9]{20}" \
   scripts/ modules/ 2>/dev/null; then
  check_fail "Hardcoded API keys found!"
else
  check_pass "No hardcoded API keys"
fi

# Check for private keys
echo -n "Checking for private keys... "
if grep -r "BEGIN.*PRIVATE KEY" scripts/ modules/ web/ 2>/dev/null; then
  check_fail "Private keys found in code!"
else
  check_pass "No private keys in code"
fi

#==============================================================================
# 9. NETWORK EXPOSURE
#==============================================================================
section "9. Network Exposure"

# Check web dashboard network binding
echo -n "Checking web dashboard network exposure... "
if [[ -f scripts/web_dashboard.py ]]; then
  if grep "host='0.0.0.0'" scripts/web_dashboard.py; then
    check_warn "Dashboard binds to all interfaces - ensure firewall configured"
  elif grep "host='127.0.0.1'" scripts/web_dashboard.py; then
    check_pass "Dashboard binds to localhost only"
  fi
fi

# Check firewall rules
echo -n "Checking firewall for web dashboard... "
if grep -q "allowedTCPPorts.*8080" modules/web/dashboard.nix 2>/dev/null; then
  if grep -q "interfaces.*lo.*8080" modules/web/dashboard.nix; then
    check_pass "Port 8080 only allowed on localhost"
  else
    check_warn "Port 8080 may be exposed externally"
  fi
fi

#==============================================================================
# 10. SYSTEMD SERVICE HARDENING
#==============================================================================
section "10. Systemd Service Hardening"

# Check new services have security features
for service_file in modules/web/dashboard.nix modules/monitoring/alerting.nix; do
  if [[ -f "$service_file" ]]; then
    echo "Checking $service_file..."
    
    if grep -q "ProtectSystem\|ProtectHome\|PrivateTmp" "$service_file"; then
      check_pass "  Service uses systemd hardening features"
    else
      check_warn "  Service missing systemd hardening"
    fi
    
    if grep -q "NoNewPrivileges=true" "$service_file"; then
      check_pass "  NoNewPrivileges enabled"
    else
      check_warn "  NoNewPrivileges not set"
    fi
  fi
done

#==============================================================================
# 11. LOG FILE SECURITY
#==============================================================================
section "11. Log File Security"

# Check log files don't contain sensitive data
echo -n "Checking logs for passwords... "
if grep -rE "password=|passwd=|pwd=" /var/lib/hypervisor/logs/ 2>/dev/null | grep -v "password_required\|password_hash"; then
  check_fail "Passwords found in log files!"
else
  check_pass "No passwords in logs"
fi

# Check log file permissions
echo -n "Checking log file permissions... "
if [[ -d /var/lib/hypervisor/logs ]]; then
  local world_readable=$(find /var/lib/hypervisor/logs -type f -perm /044 2>/dev/null | wc -l)
  if [[ $world_readable -eq 0 ]]; then
    check_pass "Log files not world-readable"
  else
    check_warn "$world_readable log files are world-readable"
  fi
fi

#==============================================================================
# 12. CODE INJECTION VULNERABILITIES
#==============================================================================
section "12. Code Injection Check"

# Check for dangerous Python constructs
if [[ -f scripts/web_dashboard.py ]]; then
  echo -n "Checking for eval/exec in Python... "
  if grep -E "\beval\(|\bexec\(" scripts/web_dashboard.py 2>/dev/null; then
    check_fail "eval() or exec() found in Python (code injection risk)"
  else
    check_pass "No eval/exec in Python code"
  fi
fi

# Check for dangerous bash constructs
echo -n "Checking for dangerous bash patterns... "
local dangerous=$(grep -rE "\$\(.*\$\{.*\}\)|\`.*\$" scripts/guided*.sh scripts/alert_manager.sh 2>/dev/null | wc -l)
if [[ $dangerous -gt 10 ]]; then
  check_warn "$dangerous instances of nested command substitution"
else
  check_pass "Minimal nested command substitution"
fi

#==============================================================================
# 13. RACE CONDITIONS
#==============================================================================
section "13. Race Conditions"

# Check for insecure temp file creation
echo -n "Checking temp file creation... "
if grep -r ">/tmp/[^$]\|cat > /tmp" scripts/guided*.sh scripts/alert*.sh scripts/web*.py 2>/dev/null | grep -v mktemp; then
  check_warn "Insecure temp file creation found"
else
  check_pass "Temp files use mktemp (secure)"
fi

# Check for TOCTOU vulnerabilities
echo -n "Checking for TOCTOU issues... "
if grep -rE "test -f.*&&.*cat\|if.*-f.*then.*rm" scripts/guided*.sh scripts/auto*.sh 2>/dev/null | wc -l | grep -q "^[3-9]"; then
  check_warn "Potential TOCTOU (time-of-check-time-of-use) issues"
else
  check_pass "No obvious TOCTOU vulnerabilities"
fi

#==============================================================================
# 14. PRIVILEGE ESCALATION
#==============================================================================
section "14. Privilege Escalation Check"

# Check for unnecessary sudo
echo -n "Checking for unnecessary sudo calls... "
local sudo_count=$(grep -r "sudo " scripts/guided*.sh scripts/alert*.sh 2>/dev/null | wc -l)
if [[ $sudo_count -gt 5 ]]; then
  check_warn "$sudo_count sudo calls in new scripts - verify necessity"
else
  check_pass "Minimal sudo usage in new scripts"
fi

# Check web dashboard doesn't call sudo
if [[ -f scripts/web_dashboard.py ]]; then
  echo -n "Checking web dashboard privilege escalation... "
  if grep -q "sudo" scripts/web_dashboard.py; then
    check_fail "Web dashboard calls sudo (privilege escalation risk!)"
  else
    check_pass "Web dashboard doesn't call sudo"
  fi
fi

#==============================================================================
# 15. DEPENDENCY SECURITY
#==============================================================================
section "15. Dependency Security"

# Check Python dependencies
if [[ -f scripts/web_dashboard.py ]]; then
  echo -n "Checking Python dependencies... "
  # Extract imports
  local imports=$(grep "^import\|^from.*import" scripts/web_dashboard.py 2>/dev/null | awk '{print $2}' | cut -d. -f1 | sort -u)
  
  # Check for risky dependencies
  if echo "$imports" | grep -iE "pickle|yaml|xml"; then
    check_warn "Using potentially risky Python libraries (pickle/yaml/xml)"
  else
    check_pass "Using safe Python libraries"
  fi
fi

#==============================================================================
# SUMMARY
#==============================================================================
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    AUDIT SUMMARY                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

log "=== AUDIT SUMMARY ==="
log "Critical issues: $ISSUES_FOUND"
log "Warnings: $WARNINGS_FOUND"

if [[ $ISSUES_FOUND -eq 0 ]] && [[ $WARNINGS_FOUND -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}✓ NO SECURITY ISSUES FOUND${NC}"
  echo ""
  echo "Your new features pass all security checks!"
  echo ""
  log "RESULT: PASS - No issues found"
  exit 0
elif [[ $ISSUES_FOUND -eq 0 ]]; then
  echo -e "${YELLOW}${BOLD}⚠ $WARNINGS_FOUND WARNING(S) FOUND${NC}"
  echo ""
  echo "No critical issues, but some warnings to review."
  echo "Check the audit log for details: $AUDIT_LOG"
  echo ""
  log "RESULT: WARN - $WARNINGS_FOUND warnings"
  exit 0
else
  echo -e "${RED}${BOLD}✗ $ISSUES_FOUND CRITICAL ISSUE(S) FOUND${NC}"
  echo -e "${YELLOW}  $WARNINGS_FOUND WARNING(S)${NC}"
  echo ""
  echo "CRITICAL ISSUES MUST BE FIXED BEFORE DEPLOYMENT!"
  echo "Review audit log: $AUDIT_LOG"
  echo ""
  log "RESULT: FAIL - $ISSUES_FOUND critical issues"
  exit 1
fi
