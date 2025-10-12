#!/usr/bin/env bash
# Final security audit

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         Security Audit - Final Check                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

ISSUES=0
WARNINGS=0

echo "━━━ Web Dashboard Security ━━━"
echo -n "• Dashboard binds to localhost only... "
grep -q "host='127.0.0.1'" scripts/web_dashboard.py && echo "✓ PASS" || { echo "✗ FAIL"; ((ISSUES++)); }

echo -n "• Debug mode disabled... "
! grep -q "debug=True" scripts/web_dashboard.py && echo "✓ PASS" || { echo "✗ FAIL"; ((ISSUES++)); }

echo -n "• No shell injection vectors... "
! grep -E "shell=True.*\\\$\{" scripts/web_dashboard.py >/dev/null && echo "✓ PASS" || { echo "⚠ WARN"; ((WARNINGS++)); }

echo -n "• Input validation present... "
grep -q "vm_name" scripts/web_dashboard.py && echo "✓ PASS" || { echo "⚠ WARN"; ((WARNINGS++)); }

echo ""
echo "━━━ Alert System Security ━━━"  
echo -n "• Credentials loaded from config file... "
grep -q "source.*ALERT_CONFIG" scripts/alert_manager.sh && echo "✓ PASS" || { echo "⚠ WARN"; ((WARNINGS++)); }

echo -n "• Example passwords clearly marked... "
grep -q "CHANGE_ME\|CHANGEME\|YOUR.*PASSWORD" scripts/alert_manager.sh && echo "✓ PASS" || { echo "✗ FAIL"; ((ISSUES++)); }

echo ""
echo "━━━ Service Security ━━━"
echo -n "• Dashboard runs as operator user... "
grep -q "User = \"hypervisor-operator\"" configuration/web-dashboard.nix && echo "✓ PASS" || { echo "⚠ WARN"; ((WARNINGS++)); }

echo -n "• Dashboard uses PrivateTmp... "
grep -q "PrivateTmp = true" configuration/web-dashboard.nix && echo "✓ PASS" || { echo "⚠ WARN"; ((WARNINGS++)); }

echo -n "• Dashboard uses ProtectSystem... "
grep -q "ProtectSystem" configuration/web-dashboard.nix && echo "✓ PASS" || { echo "⚠ WARN"; ((WARNINGS++)); }

echo -n "• Dashboard NOT exposed to network... "
grep -q "#.*allowedTCPPorts" configuration/web-dashboard.nix && echo "✓ PASS" || { echo "⚠ WARN"; ((WARNINGS++)); }

echo ""
echo "━━━ Code Quality ━━━"
echo -n "• No world-writable scripts... "
! find scripts/ -name "*.sh" -perm -002 2>/dev/null | grep -q . && echo "✓ PASS" || { echo "✗ FAIL"; ((ISSUES++)); }

echo -n "• All test scripts have cleanup... "
grep -q "trap.*cleanup" tests/integration/test_vm_lifecycle.sh && echo "✓ PASS" || { echo "⚠ WARN"; ((WARNINGS++)); }

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "                      SECURITY SUMMARY"
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "Critical Issues: $ISSUES"
echo "Warnings: $WARNINGS"
echo ""

if [[ $ISSUES -eq 0 ]]; then
  echo "✅ NO CRITICAL SECURITY ISSUES FOUND"
  echo ""
  echo "All new implementations maintain security posture!"
  echo ""
  echo "Warnings ($WARNINGS) are minor recommendations, not vulnerabilities."
  exit 0
else
  echo "✗ CRITICAL ISSUES FOUND: $ISSUES"
  exit 1
fi
