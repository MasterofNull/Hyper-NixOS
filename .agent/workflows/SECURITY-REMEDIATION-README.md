# Security Remediation Workflow

Generated: 2026-03-23
Status: **ACTIVE**

## Quick Start

```bash
# Check current security status
bash scripts/security/security-remediation-check.sh

# View the full remediation plan
cat .agents/plans/phase-06-security-remediation.md

# Check AI harness status
aq-qa 0 --json
```

## Current Baseline (2026-03-23)

| Metric | Count | Target |
|--------|-------|--------|
| ShellCheck Errors | 42 | 0 |
| ShellCheck Warnings | 938 | <200 |
| ShellCheck Notes | 678 | <300 |
| Total Shell Issues | 1,658 | <500 |
| eval usages | 38 | <10 |

## Priority Order

1. **P0 - Critical Errors (42)**: Fix `local` outside functions, array concatenation issues
2. **P1 - SC2155 (735)**: Separate declare and assign statements
3. **P1 - SC2162 (241)**: Add `-r` flag to `read` commands
4. **P1 - SC2086 (180)**: Quote variable expansions
5. **P1 - Security Patterns (38)**: Audit and reduce `eval` usages

## Files to Fix First

These files have the most issues and should be prioritized:

1. `scripts/prom_exporter_enhanced.sh` - 40 issues
2. `scripts/setup/unified-network-wizard.sh` - 36 issues
3. `scripts/resource_reporter.sh` - 36 issues
4. `scripts/lib/network-discovery.sh` - 32 issues
5. `scripts/system_health_check.sh` - 31 issues

## AI Harness Integration

The security baseline has been stored in the AI harness semantic memory:
- Memory ID: `8b433d52-4ba9-47b5-abcd-bfd24eb2e3dc`
- Type: `semantic`

### Query Security Context

```bash
API_KEY=$(cat /run/secrets/hybrid_coordinator_api_key | tr -d '\n')

# Get security-related hints
curl -H "Authorization: Bearer $API_KEY" \
  "http://localhost:8003/hints"

# Plan security workflow
curl -H "Authorization: Bearer $API_KEY" \
  "http://localhost:8003/workflow/plan?q=shellcheck+fix+SC2155"
```

## Validation Gates

After making changes, validate with:

```bash
# Quick validation
nix flake check --no-build
bash tests/run_all_tests.sh

# Full CI validation
bash tests/ci_validation.sh

# Security-specific check
bash scripts/security/security-remediation-check.sh
```

## Related Files

| File | Purpose |
|------|---------|
| [phase-06-security-remediation.md](./../.agents/plans/phase-06-security-remediation.md) | Full remediation plan |
| [security-remediation-tracker.json](./security-remediation-tracker.json) | Machine-readable progress |
| [security-remediation-check.sh](./../../scripts/security/security-remediation-check.sh) | Progress checker script |

## Upstream Contribution Targets

Once internal remediation is complete:
- NixOS/nixpkgs - Module security improvements
- Linux kernel - Configuration hardening
- COSMIC OS - Desktop security patterns
- Package maintainers - Upstream bug reports

## Contact

Owner: MasterofNull
Repository: https://github.com/MasterofNull/Hyper-NixOS
