# Phase 06: Security Remediation Master Plan

Generated: 2026-03-23
Status: **ACTIVE**
Priority: **HIGH**
Target: 595+ Code Scanning Issues

## Executive Summary

This phase addresses comprehensive security remediation across the Hyper-NixOS codebase, preparing the system for security research, upstream contribution, and production hardening.

## Current Security Assessment

### Issue Breakdown by Category

| Category | Count | Severity | Priority |
|----------|-------|----------|----------|
| Shell Script Issues (ShellCheck) | 1,655 | Mixed | P1 |
| - Errors | 42 | Critical | P0 |
| - Warnings | 936 | High | P1 |
| - Notes (Info) | 677 | Medium | P2 |
| Go Code Issues | TBD | Medium | P2 |
| Python Code Issues | TBD | Medium | P2 |
| Nix Module Issues | 0 | N/A | - |

### Top ShellCheck Violations

| Code | Count | Description | Fix Complexity |
|------|-------|-------------|----------------|
| SC2155 | 735 | Declare and assign separately | Low |
| SC2162 | 241 | read without -r mangles backslashes | Low |
| SC2086 | 180 | Double quote to prevent globbing | Low |
| SC2034 | 76 | Unused variables | Low |
| SC1091 | 62 | Not following sourced files | Info |
| SC2126 | 35 | grep|wc -l instead of grep -c | Low |
| SC2168 | 28 | 'local' outside functions | Medium |
| SC2129 | 26 | Consider grouping redirections | Low |
| SC2199 | 14 | Arrays in [[ ]] | Medium |
| SC2164 | 16 | cd without || exit | Low |

### Files with Most Issues (Top 10)

1. `scripts/prom_exporter_enhanced.sh` - 40 issues
2. `scripts/setup/unified-network-wizard.sh` - 36 issues
3. `scripts/resource_reporter.sh` - 36 issues
4. `scripts/lib/network-discovery.sh` - 32 issues
5. `scripts/system_health_check.sh` - 31 issues
6. `scripts/security/defensive-validation.sh` - 31 issues
7. `scripts/network-discover.sh` - 31 issues
8. `scripts/hv-stream-migrate.sh` - 30 issues
9. `scripts/security/advanced-security-functions.sh` - 28 issues
10. `scripts/lib/system_discovery.sh` - 27 issues

### Security-Critical Patterns Found

| Pattern | Count | Risk Level |
|---------|-------|------------|
| `eval` usage | 36 | HIGH |
| `rm -rf` patterns | 15+ | MEDIUM |
| Curl/wget command substitution | 9 | MEDIUM |
| `chmod 777` | 0 | - |
| Hardcoded credentials | 0 | - |

## Remediation Strategy

### Slice 6.1: Critical Errors (P0)

**Objective**: Fix all 42 error-level ShellCheck issues
**Estimated Scope**: 5 files

Files to fix:
- [ ] `tests/run_comprehensive_tests.sh` - 3 errors (local outside function)
- [ ] `scripts/comprehensive-setup-wizard.sh` - 6 errors (array concatenation)
- [ ] `scripts/security/advanced-security-functions.sh` - 1 error
- [ ] `scripts/feature-manager-wizard.sh` - 4 errors
- [ ] `scripts/audit/security_audit.sh` - 12 errors (local outside function)
- [ ] `scripts/validate_hypervisor_install.sh` - 4 errors

**Exit Criteria**: `shellcheck --severity=error` returns 0 issues

### Slice 6.2: High-Priority Warnings (P1)

**Objective**: Fix top 5 warning categories (1,150+ issues)

Sub-slices:
- 6.2.1: SC2155 - Separate declare/assign (735 instances)
- 6.2.2: SC2162 - Add -r flag to read (241 instances)
- 6.2.3: SC2086 - Quote expansions (180 instances)
- 6.2.4: SC2034 - Remove/use unused vars (76 instances)
- 6.2.5: SC2168 - Wrap local in functions (28 instances)

**Exit Criteria**: Warning count < 200

### Slice 6.3: Security Pattern Hardening (P1)

**Objective**: Audit and harden security-critical patterns

Tasks:
- [ ] Audit 36 `eval` usages - replace with safer alternatives where possible
- [ ] Review all `rm -rf` patterns for variable safety
- [ ] Validate curl/wget command substitution for injection risks
- [ ] Ensure no secrets in scripts

**Exit Criteria**: Security audit passes with 0 critical findings

### Slice 6.4: Go API Security (P2)

**Objective**: Add security scanning for Go code

Tasks:
- [ ] Install/configure gosec
- [ ] Run staticcheck analysis
- [ ] Review authentication handlers
- [ ] Validate input sanitization
- [ ] Check for SQL injection patterns

**Exit Criteria**: gosec returns 0 high-severity issues

### Slice 6.5: Python Security (P2)

**Objective**: Scan Python code for vulnerabilities

Tasks:
- [ ] Install/configure bandit
- [ ] Run pip-audit on dependencies
- [ ] Review web dashboard code
- [ ] Check for injection vulnerabilities

**Exit Criteria**: bandit returns 0 high-severity issues

### Slice 6.6: AI Harness Security Integration (P1)

**Objective**: Configure AI harness for continuous security monitoring

Tasks:
- [ ] Store security baseline in AIDB
- [ ] Configure automated scanning workflows
- [ ] Set up security regression detection
- [ ] Create security eval scorecard

**Exit Criteria**: `aq-qa security` phase implemented

## Upstream Contribution Preparation

### Phase 6.7: Research Infrastructure

**Objective**: Prepare for upstream security contributions

Components:
- [ ] NixOS module security patterns
- [ ] Linux kernel security configuration review
- [ ] Package hardening recommendations
- [ ] CVE tracking workflow

### Phase 6.8: Contribution Workflow

**Objective**: Establish upstream contribution pipeline

Tasks:
- [ ] Fork management for nixpkgs
- [ ] Contribution guidelines documentation
- [ ] Patch formatting standards
- [ ] Review process automation

## AI Harness Integration

### Available Endpoints

| Endpoint | Purpose | Usage |
|----------|---------|-------|
| `/hints` | Context-aware suggestions | Security remediation guidance |
| `/workflow/plan` | Workflow planning | Phase orchestration |
| `/memory/store` | Persist context | Security findings storage |
| `/memory/recall` | Retrieve context | Previous findings retrieval |
| `/discovery/capabilities` | Feature discovery | Tool recommendations |

### Workflow Commands

```bash
# Check harness health
aq-qa 0 --json

# Get security hints
API_KEY=$(cat /run/secrets/hybrid_coordinator_api_key | tr -d '\n')
curl -H "Authorization: Bearer $API_KEY" "http://localhost:8003/hints"

# Plan security workflow
curl -H "Authorization: Bearer $API_KEY" \
  "http://localhost:8003/workflow/plan?q=security+remediation"

# Store security findings
curl -X POST -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"key":"security-baseline","data":{}}' \
  "http://localhost:8003/memory/store"
```

## Validation Gates

### Per-Slice Validation

```bash
# Slice 6.1: Error check
find . -name "*.sh" | xargs shellcheck --severity=error 2>&1 | grep -c ": error:" | [ $(cat) -eq 0 ]

# Slice 6.2: Warning count
find . -name "*.sh" | xargs shellcheck --severity=warning 2>&1 | wc -l | [ $(cat) -lt 200 ]

# Slice 6.3: Security patterns
grep -rn "eval\s" --include="*.sh" . | wc -l | [ $(cat) -lt 10 ]

# Full validation
nix flake check --no-build
bash tests/run_all_tests.sh
bash tests/ci_validation.sh
```

## Progress Tracking

### Completion Metrics

| Metric | Initial | Current | Target |
|--------|---------|---------|--------|
| ShellCheck Errors | 42 | - | 0 |
| ShellCheck Warnings | 936 | - | <200 |
| ShellCheck Notes | 677 | - | <300 |
| Eval usages | 36 | - | <10 |
| Go security issues | TBD | - | 0 |
| Python security issues | TBD | - | 0 |

### Sprint Tracking

| Sprint | Focus | Status | Issues Fixed |
|--------|-------|--------|--------------|
| S1 | Critical Errors | PENDING | 0/42 |
| S2 | SC2155 fixes | PENDING | 0/735 |
| S3 | SC2162+SC2086 | PENDING | 0/421 |
| S4 | Security patterns | PENDING | 0/36 |
| S5 | Go/Python scan | PENDING | - |
| S6 | AI integration | PENDING | - |

## Notes

- All fixes must pass existing CI validation (153 checks)
- Maintain backward compatibility with existing scripts
- Document any behavior changes
- Use AI harness for pattern detection and fix suggestions
- Store security findings in AIDB for future reference

## References

- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
- [AIDB Endpoints](http://localhost:8002/docs)
- [Hybrid Coordinator](http://localhost:8003/docs)
- [Project PRD](./../.agent/PROJECT-PRD.md)
- [ROADMAP](./ROADMAP.md)
