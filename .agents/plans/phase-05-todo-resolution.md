# Phase 05: TODO Resolution

**Priority**: P2 - Medium
**Status**: Complete
**Estimated Effort**: Medium
**Dependencies**: Phases 01-03 complete

## Objective
Address all validated TODOs in the codebase by implementing, documenting, or removing them.

## Scope Lock
- **In scope**: 30 TODOs across tests and modules
- **Out of scope**: New feature development
- **Constraints**: Maintain existing functionality

## Context References
- Files to read first:
  - All files with TODOs (see list below)
- Docs to read first:
  - Module documentation for context

## Current TODO Inventory

Validated on 2026-03-21 with:
`rg -n "TODO" tests modules scripts --glob '*.nix' --glob '*.sh' | wc -l`

Current count: **17**

### Test Module TODOs (13 items)
Files in `tests/modules/`:
1. `test_input.nix` - Add module-specific tests
2. `test_remote-desktop.nix` - Add module-specific tests
3. `test_keymap-sanitizer.nix` - Add module-specific tests
4. `test_directories.nix` - Add module-specific tests
5. `test_optimized-system.nix` - Add module-specific tests
6. `test_educational-content.nix` - Add module-specific tests
7. `test_adaptive-docs.nix` - Add module-specific tests
8. `test_hypervisor-base.nix` - Add module-specific tests
9. `test_options.nix` - Add module-specific tests
10. `test_base.nix` - Add module-specific tests
11. `test_feature-categories.nix` - Add module-specific tests
12. `test_portable-base.nix` - Add module-specific tests
13. `test_admin-integration.nix` - Add module-specific tests

### Module TODOs (1 item)
1. `modules/core/optimized-system.nix` - Configure proper seal mechanism

### Script TODOs (2 items)
1. `scripts/setup/mac-spoofing-wizard.sh` - Remove configuration
2. `scripts/setup/ip-spoofing-wizard.sh` - Remove configuration

## Steps

### Slice 5.1: Test Module TODOs
**Batch 5.1.A: Core Module Tests**
1. Implement tests for `test_base.nix`
2. Implement tests for `test_options.nix`
3. Implement tests for `test_hypervisor-base.nix`

**Batch 5.1.B: Feature Module Tests**
1. Implement tests for `test_feature-categories.nix`
2. Implement tests for `test_directories.nix`
3. Implement tests for `test_admin-integration.nix`

**Batch 5.1.C: UI/UX Module Tests**
1. Implement tests for `test_input.nix`
2. Implement tests for `test_keymap-sanitizer.nix`
3. Implement tests for `test_remote-desktop.nix`

**Batch 5.1.D: Documentation Module Tests**
1. Implement tests for `test_adaptive-docs.nix`
2. Implement tests for `test_educational-content.nix`
3. Implement tests for `test_portable-base.nix`
4. Implement tests for `test_optimized-system.nix`

### Slice 5.2: Core Module TODOs
1. Configure proper seal mechanism or document as future work

### Slice 5.3: Script TODOs
1. Implement or remove mac-spoofing removal config
2. Implement or remove ip-spoofing removal config

## Validation
- **Syntax**: `nix flake check`
- **Tests**: `bash tests/run_all_tests.sh`
- **Smoke**: `grep -r "TODO" --include="*.nix" --include="*.sh" | wc -l` returns 0

## Evidence
- Files changed: (all TODO files)
- Commands run: grep, tests
- Output snippets: Zero TODOs remaining

## Commit Message Template
```
chore: resolve all TODO items in codebase

Addressed 30 TODOs across test modules, core modules, and scripts:
- Implemented module-specific tests for 13 test files
- Fixed vendorSha256 and seal mechanism configuration
- Implemented spoofing wizard removal logic
```

## Rollback
- `git checkout` individual files
