# Phase 02: Test Suite Fixes

**Priority**: P1 - High
**Status**: Complete
**Estimated Effort**: Medium
**Dependencies**: Phase 01 complete

## Objective
Fix all failing tests to achieve 100% test pass rate (5/5).

## Scope Lock
- **In scope**: Fix 3 failing tests
- **Out of scope**: New test creation, test refactoring
- **Constraints**: Preserve existing test behavior

## Context References
- Files to read first:
  - `tests/run_all_tests.sh`
  - `tests/integration/test_security_model.sh`
  - `tests/integration/test_system_installer.sh`
  - `tests/unit/test_common.sh`
- Docs to read first:
  - `tests/test-helper.bash`
  - `tests/lib/` directory

## Current State
```
Passed:  5
Failed:  0
Skipped: 0
```

Validated failure causes:
- `test_security_model` calls `test_info`, which is missing from `tests/lib/test_helpers.sh`
- `test_system_installer` uses helper APIs not implemented in `tests/lib/test_helpers.sh`
- `test_common` has a syntax defect near EOF (`fi}`) and needs a direct repair before logic-level assertions matter

## Steps

### Slice 2.1: Analyze test_security_model Failure
1. Run test in verbose mode to capture error
2. Fix missing helper coverage in `tests/lib/test_helpers.sh`
3. Verify the test no longer fails on missing helper functions
4. Verify test passes

### Slice 2.2: Analyze test_system_installer Failure
1. Run test in verbose mode
2. Add or align helper functions used by installer integration tests
3. Fix or mock missing requirements without changing intended test behavior
4. Verify test passes

### Slice 2.3: Analyze test_common Failure
1. Run `tests/unit/test_common.sh` directly
2. Compare with passing `test_common_ci.sh`
3. Repair syntax / EOF defect, then resolve any remaining logic divergence
4. Verify test passes

### Slice 2.4: Full Test Suite Validation
1. Run `bash tests/run_all_tests.sh`
2. Verify 5/5 pass
3. Document any flaky tests

## Validation
- **Syntax**: shellcheck on modified test files
- **Tests**: `bash tests/run_all_tests.sh`
- **Smoke**: All 5 tests pass

## Evidence
- Files changed: test helper and test harness files
- Commands run: individual failing tests and `bash tests/run_all_tests.sh`
- Output snippets: full suite passes 5/5

## Commit Message Template
```
fix(tests): resolve failing integration and unit tests

- Added missing integration-test helpers
- Repaired unit test syntax / parity issues
- Preserved existing test intent

All 5 tests now pass.
```

## Rollback
- `git checkout tests/`
Completion notes:
- missing helper coverage was repaired
- installer integration test was made repo-safe
- `test_common.sh` was aligned with the CI-safe harness pattern
- full suite now passes with `bash tests/run_all_tests.sh`
