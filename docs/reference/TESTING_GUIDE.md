# Testing Guide for Contributors

**Purpose:** Ensure code quality and prevent regressions through automated testing

---

## Table of Contents

- [Overview](#overview)
- [Testing Infrastructure](#testing-infrastructure)
- [Running Tests](#running-tests)
- [Writing Tests](#writing-tests)
- [CI/CD Pipeline](#cicd-pipeline)
- [Test Coverage](#test-coverage)

---

## Overview

The hypervisor project uses multiple testing strategies:

1. **ShellCheck** - Static analysis for shell scripts
2. **BATS** - Unit tests for bash functions
3. **Integration Tests** - End-to-end VM lifecycle tests
4. **Rust Tests** - Unit and integration tests for Rust tools
5. **Nix Build Tests** - Configuration validation

---

## Testing Infrastructure

### ShellCheck (Static Analysis)

**Purpose:** Catch common bash errors before they reach production

**What it checks:**
- Syntax errors
- Unsafe variable usage
- Missing quotes
- Command existence
- Return code handling

**Files checked:** All `scripts/*.sh`

**Configuration:** `.github/workflows/shellcheck.yml`

### BATS (Bash Automated Testing System)

**Purpose:** Unit test bash functions

**Framework:** https://github.com/bats-core/bats-core

**Test files:** `tests/unit/*.bats`

**Helper functions:** `tests/test-helper.bash`

### Integration Tests

**Purpose:** Test complete workflows end-to-end

**Test files:** `tests/integration/*.sh`

**What they test:**
- VM creation and deletion
- Network setup
- ISO management
- Disk operations

### Rust Tests

**Purpose:** Test Rust CLI tools (vmctl, isoctl)

**Command:** `cargo test`

**Location:** `tools/`

---

## Running Tests

### Run All Tests

```bash
# Complete test suite
./run-all-tests.sh

# Or individually:
```

### ShellCheck

```bash
# Check all scripts
shellcheck scripts/*.sh

# Check specific script
shellcheck scripts/menu.sh

# With specific severity
shellcheck --severity=warning scripts/*.sh
```

### Unit Tests (BATS)

```bash
# Install BATS (if needed)
nix-env -iA nixpkgs.bats

# Run all unit tests
bats tests/unit/*.bats

# Run specific test file
bats tests/unit/test-vm-validation.bats

# Verbose output
bats --verbose tests/unit/*.bats
```

### Integration Tests

```bash
# Run all integration tests
for test in tests/integration/*.sh; do
  bash "$test"
done

# Run specific test
bash tests/integration/test-vm-lifecycle.sh
```

### Rust Tests

```bash
# Run all Rust tests
cd tools
cargo test --all

# Run specific crate tests
cargo test --package vmctl

# Run with output
cargo test -- --nocapture

# Run clippy (linter)
cargo clippy --all -- -D warnings
```

### Nix Build Tests

```bash
# Check flake
nix flake check

# Build configuration
nix build .#nixosConfigurations.hypervisor-x86_64.config.system.build.toplevel

# Build ISO (if configured)
nix build .#iso
```

---

## Writing Tests

### ShellCheck Configuration

**File:** `.shellcheckrc` (create in project root)

```bash
# Disable specific checks
disable=SC1090  # Can't follow dynamic sources
disable=SC1091  # Not following sourced files
disable=SC2034  # Unused variables (may be used in sourced files)

# Shell to check as
shell=bash

# Enable all optional checks
enable=all
```

### Writing BATS Tests

**Template:**

```bash
#!/usr/bin/env bats

load ../test-helper

@test "Description of what you're testing" {
  # Arrange - Set up test conditions
  local test_file=$(create_test_profile "test-vm")
  
  # Act - Perform the action
  run jq -r '.name' "$test_file"
  
  # Assert - Verify results
  [ "$status" -eq 0 ]
  [ "$output" = "test-vm" ]
}

@test "Test edge case" {
  # Test error handling
  run command_that_should_fail
  
  [ "$status" -ne 0 ]
  [[ "$output" == *"expected error message"* ]]
}
```

**Available assertions:**

```bash
# Status checks
[ "$status" -eq 0 ]     # Command succeeded
[ "$status" -ne 0 ]     # Command failed

# Output checks
[ "$output" = "exact" ]              # Exact match
[[ "$output" == *"contains"* ]]      # Contains text
[[ "$output" =~ regex ]]             # Regex match

# File checks
[ -f "$file" ]          # File exists
[ ! -f "$file" ]        # File doesn't exist
[ -d "$dir" ]           # Directory exists
[ -x "$script" ]        # File is executable

# Custom assertions (from test-helper.bash)
assert_success          # Assert command succeeded
assert_failure          # Assert command failed
assert_output_contains "text"  # Output contains text
assert_file_exists "$path"     # File exists
```

### Writing Integration Tests

**Template:**

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "Test: VM Lifecycle"
echo "========================================"

# Setup
TEST_VM="test-vm-$$"
cleanup() {
  virsh destroy "$TEST_VM" 2>/dev/null || true
  virsh undefine "$TEST_VM" 2>/dev/null || true
}
trap cleanup EXIT

# Test 1: Create VM
echo "Creating VM..."
# ... create VM logic ...
if virsh list --all | grep -q "$TEST_VM"; then
  echo "  ✓ VM created"
else
  echo "  ✗ VM creation failed"
  exit 1
fi

# Test 2: Start VM
echo "Starting VM..."
# ... start logic ...

# Test 3: Verify running
echo "Verifying VM state..."
# ... verification logic ...

echo ""
echo "All tests passed! ✓"
```

### Writing Rust Tests

**Template:**

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_feature() {
        // Arrange
        let input = "test data";
        
        // Act
        let result = function_under_test(input);
        
        // Assert
        assert_eq!(result, expected_value);
    }

    #[test]
    #[should_panic(expected = "error message")]
    fn test_error_handling() {
        // Test that function panics appropriately
        function_that_should_fail();
    }
}
```

---

## CI/CD Pipeline

### GitHub Actions Workflows

**Files:**
- `.github/workflows/shellcheck.yml` - Shell script linting
- `.github/workflows/tests.yml` - Unit and integration tests
- `.github/workflows/rust-tests.yml` - Rust testing and linting
- `.github/workflows/nix-build.yml` - NixOS configuration build

### Workflow Triggers

**All workflows run on:**
- Push to `main`, `develop`, or `cursor/**` branches
- Pull requests to `main` or `develop`
- Specific file changes (path filters)

### Status Checks

All PRs must pass:
- ✅ ShellCheck analysis
- ✅ Unit tests
- ✅ Integration tests (when available)
- ✅ Rust tests and clippy
- ✅ Nix build

### Local Pre-commit Checks

**Recommended:** Run tests before committing

```bash
# Create .git/hooks/pre-commit
#!/bin/bash
echo "Running pre-commit checks..."

# ShellCheck
echo "1. ShellCheck..."
shellcheck scripts/*.sh || exit 1

# Unit tests (if BATS installed)
if command -v bats >/dev/null; then
  echo "2. Unit tests..."
  bats tests/unit/*.bats || exit 1
fi

# Rust tests
if [ -d "tools" ]; then
  echo "3. Rust tests..."
  cd tools && cargo test --all || exit 1
fi

echo "✓ All checks passed"
```

---

## Test Coverage

### Current Coverage

**Shell Scripts:** ~80%
- Core functions tested
- Validation functions tested
- Error handling tested

**Rust Tools:** ~60%
- Main functions tested
- Need more edge case tests

**Integration:** ~40%
- VM lifecycle tested
- Need network, storage, VFIO tests

### Coverage Goals

**Target:** 80%+ for all components

**Priority areas:**
1. VM creation and validation
2. Network setup
3. Security features
4. Error handling
5. Resource management

---

## Best Practices

### Test Naming

```bash
# Good test names
@test "VM name validation - empty name rejected"
@test "JSON parsing - defaults applied correctly"
@test "Disk creation - handles insufficient space"

# Bad test names
@test "test1"
@test "works"
@test "check VM"
```

### Test Independence

```bash
# Good - each test is independent
@test "test A" {
  create_test_vm "test-a"
  # test logic
  cleanup_test_vm "test-a"
}

@test "test B" {
  create_test_vm "test-b"
  # test logic
  cleanup_test_vm "test-b"
}

# Bad - tests depend on each other
@test "create VM" {
  create_vm  # VM persists
}

@test "use VM" {
  use_vm  # Depends on previous test
}
```

### Test Data

```bash
# Good - use test-specific data
TEST_VM_NAME="test-vm-$$"  # Unique per run
TEST_PROFILE="/tmp/test-$$.json"

# Bad - use production data
TEST_VM_NAME="production-vm"  # Could conflict!
TEST_PROFILE="/var/lib/hypervisor/vm-profiles/real.json"
```

### Cleanup

```bash
# Always clean up, even on failure
cleanup() {
  rm -f "$TEST_FILES"
  virsh destroy "$TEST_VM" 2>/dev/null || true
}

trap cleanup EXIT
```

---

## Troubleshooting Tests

### Test Failures

```bash
# Run with verbose output
bats --verbose tests/unit/failing-test.bats

# Run single test
bats --filter "specific test name" tests/unit/*.bats

# Show test output
bats --show-output-of-passing-tests tests/unit/*.bats
```

### CI Failures

1. **Check GitHub Actions logs** - Detailed output available
2. **Reproduce locally** - Run same commands
3. **Check dependencies** - May differ in CI
4. **Review recent changes** - What changed?

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| **Test timeout** | Long-running operation | Add timeout: `timeout 30 command` |
| **Permission denied** | Missing sudo in CI | Mock privileged commands |
| **Command not found** | Missing dependency | Add to CI setup steps |
| **Flaky test** | Race condition | Add proper waits/sleeps |
| **State pollution** | Tests not independent | Improve cleanup |

---

## Contributing

### Before Submitting PR

1. **Run all tests locally**
   ```bash
   shellcheck scripts/*.sh
   bats tests/unit/*.bats
   bash tests/integration/*.sh
   cd tools && cargo test
   ```

2. **Add tests for new features**
   - Unit tests for new functions
   - Integration tests for new workflows
   - Update existing tests if behavior changes

3. **Ensure tests pass in CI**
   - Check GitHub Actions status
   - Fix any failures before merge

### Test Requirements

**For new features:**
- At least one unit test
- Integration test if user-facing
- Documentation updated

**For bug fixes:**
- Test that reproduces the bug
- Test passes after fix
- Regression test added

---

## Resources

- **BATS Documentation:** https://bats-core.readthedocs.io/
- **ShellCheck Wiki:** https://www.shellcheck.net/wiki/
- **Rust Testing:** https://doc.rust-lang.org/book/ch11-00-testing.html
- **GitHub Actions:** https://docs.github.com/en/actions

---

**Remember:** Tests are documentation that validates itself. Write clear, maintainable tests that explain what the code should do.
