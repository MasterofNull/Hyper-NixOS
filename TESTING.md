# Testing Guide - Hyper-NixOS

This document describes the testing infrastructure, requirements, and procedures for Hyper-NixOS.

## 🎯 Testing Requirements

**CRITICAL REQUIREMENT #7**: Minimum 80% test coverage is **MANDATORY** for deployment.

From `docs/dev/CRITICAL_REQUIREMENTS.md`:
- Unit tests: 80% coverage
- Integration tests: All critical paths
- Security tests: All auth/privilege paths
- Performance tests: Baseline metrics
- Documentation tests: All examples must work

## 📊 Current Test Coverage

Run the comprehensive test suite to see current coverage:

```bash
./tests/run_comprehensive_tests.sh
```

The test runner will display:
- Module coverage percentage
- Script coverage percentage
- Overall coverage percentage
- Gap analysis (if below 80%)
- Number of additional tests needed

### Coverage Calculation

```
Module Coverage = (Tested Modules / Total Modules) × 100
Script Coverage = (Tested Scripts / Total Scripts) × 100
Overall Coverage = (Tested Items / Total Items) × 100
```

**Target:** 80% overall coverage

## 🧪 Test Structure

### Test Organization

```
tests/
├── run_comprehensive_tests.sh    # Main test runner with coverage reporting
├── lib/
│   └── test_helpers.bash          # Shared test utilities
├── modules/
│   ├── test_template.nix          # Template for module tests
│   ├── test_*.nix                 # Module tests (NixOS VM tests)
│   └── ...
├── scripts/
│   ├── test_script_template.bats  # Template for script tests
│   ├── test_*.bats                # Script tests (BATS framework)
│   └── ...
├── integration/
│   ├── test_complete_system.nix   # End-to-end integration tests
│   └── ...
└── results/
    ├── coverage-*.txt             # Coverage reports
    └── *.log                      # Test execution logs
```

### Test Types

1. **Module Tests** (`.nix` files):
   - Test NixOS modules in isolated VMs
   - Verify service activation
   - Check configuration application
   - Validate system state

2. **Script Tests** (`.bats` files):
   - Test bash scripts with BATS framework
   - Verify script behavior
   - Test error handling
   - Validate output

3. **Integration Tests**:
   - Test complete system workflows
   - Multi-component interactions
   - End-to-end scenarios

4. **Security Tests**:
   - Privilege separation verification
   - Authentication and authorization paths
   - Threat detection and response

## 🚀 Running Tests

### Run All Tests

```bash
cd /path/to/Hyper-NixOS
./tests/run_comprehensive_tests.sh
```

### Run Specific Test Categories

**Module tests only:**
```bash
for test in tests/modules/test_*.nix; do
  nix-build "$test"
done
```

**Script tests only:**
```bash
bats tests/scripts/test_*.bats
```

**Integration tests:**
```bash
nix-build tests/integration/test_complete_system.nix
```

**Security tests:**
```bash
./tests/integration-test-security.sh
```

### Run Individual Tests

**Single module test:**
```bash
nix-build tests/modules/test_password_protection.nix
```

**Single script test:**
```bash
bats tests/scripts/test_hv_cli.bats
```

## 📝 Writing Tests

### Creating a Module Test

1. Copy the template:
```bash
cp tests/modules/test_template.nix tests/modules/test_your_module.nix
```

2. Edit the test:
```nix
{ pkgs, lib, ... }:

{
  name = "your-module-test";

  nodes.machine = { config, pkgs, ... }: {
    imports = [
      ../../modules/path/to/your-module.nix
    ];

    # Enable your module
    hypervisor.yourModule.enable = true;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Your test assertions
    with subtest("Feature works"):
        machine.succeed("systemctl is-active your-service.service")

    print("✓ Test passed")
  '';
}
```

3. Run your test:
```bash
nix-build tests/modules/test_your_module.nix
```

### Creating a Script Test

1. Copy the template:
```bash
cp tests/scripts/test_script_template.bats tests/scripts/test_your_script.bats
```

2. Edit the test:
```bash
#!/usr/bin/env bats

load ../lib/test_helpers.bash

@test "script exists and is executable" {
    [ -f "scripts/your-script.sh" ]
    [ -x "scripts/your-script.sh" ]
}

@test "script has proper error handling" {
    run grep "set -euo pipefail" scripts/your-script.sh
    [ "$status" -eq 0 ]
}

@test "your specific functionality" {
    run bash scripts/your-script.sh --test-flag
    [ "$status" -eq 0 ]
    [[ "$output" == *"expected output"* ]]
}
```

3. Run your test:
```bash
bats tests/scripts/test_your_script.bats
```

## 🎯 Test Coverage Goals

### Module Tests (Target: 80%)

**Critical Modules** (MUST be tested):
- ✅ Security modules (password-protection, privilege-separation, threat-detection)
- ✅ Virtualization modules (libvirt, performance)
- ✅ Core modules (system, packages, first-boot)
- ✅ Hardware modules (laptop, desktop, server, ARM)
- ✅ Feature modules (feature-manager, progress-tracking)

**Important Modules** (should be tested):
- GUI modules (desktop, remote-desktop)
- Monitoring modules
- Storage modules
- Network modules

### Script Tests (Target: 80%)

**Critical Scripts** (MUST be tested):
- ✅ hv CLI
- ✅ install.sh
- ✅ Wizards (setup, security, network, first-boot, VM creation)

**Important Scripts** (should be tested):
- Backup scripts
- Migration scripts
- Utility scripts

### Integration Tests

**Critical Paths**:
- ✅ Complete system deployment
- VM lifecycle (create, start, stop, delete)
- Security workflows (user creation, privilege changes)
- Network configuration changes
- Backup and restore

## 📈 Coverage Tracking

Coverage is automatically tracked when running `./tests/run_comprehensive_tests.sh`.

### Current Coverage Status

**As of last test run:**
- Module Coverage: `X%` (X/113 modules)
- Script Coverage: `Y%` (Y/186 scripts)
- Overall Coverage: `Z%` (X+Y/299 items)

**Gap to 80% target:** `~N more tests needed`

### Viewing Coverage Reports

Latest coverage report:
```bash
cat tests/results/coverage-*.txt | tail -1
```

## 🔒 Security Test Requirements

All security-critical paths MUST have tests:

1. **Authentication**:
   - User login validation
   - Password protection mechanisms
   - Session management

2. **Authorization**:
   - Privilege separation (admin vs operator)
   - Polkit rules enforcement
   - Sudo requirements

3. **Threat Detection**:
   - Behavioral analysis
   - Anomaly detection
   - Response actions

4. **Data Protection**:
   - Password wipe prevention
   - Credential storage security
   - Encryption verification

## 🚦 Continuous Integration

### Pre-commit Checks

Before committing code, run:
```bash
./tests/run_comprehensive_tests.sh
```

**Commit is blocked if:**
- Any tests fail
- Coverage drops below 80%
- Syntax errors in Nix or shell scripts

### CI/CD Pipeline

Automated checks on every PR/MR:
1. Run all tests
2. Calculate coverage
3. Verify 80% threshold
4. Check documentation sync
5. Security review for sensitive changes

## 🐛 Debugging Test Failures

### Module Test Failures

1. Check the test log:
```bash
cat tests/results/test_your_module.log
```

2. Run interactively:
```bash
nix-build tests/modules/test_your_module.nix --show-trace
```

3. Access the VM:
```bash
# Add to testScript:
machine.shell_interact()
```

### Script Test Failures

1. Run with verbose output:
```bash
bats -t tests/scripts/test_your_script.bats
```

2. Add debug output to your test:
```bash
@test "debugging example" {
    run your_command
    echo "Status: $status"
    echo "Output: $output"
    [ "$status" -eq 0 ]
}
```

## 📚 Test Best Practices

### DO:
- ✅ Test one thing per test
- ✅ Use descriptive test names
- ✅ Clean up after tests
- ✅ Use test helpers for common operations
- ✅ Test both success and failure paths
- ✅ Document complex test scenarios

### DON'T:
- ❌ Depend on external services
- ❌ Rely on specific timing (use retries)
- ❌ Leave test artifacts
- ❌ Test implementation details (test behavior)
- ❌ Skip tests without good reason

## 📞 Getting Help

- **Test failures**: Check test logs in `tests/results/`
- **Coverage questions**: Run `./tests/run_comprehensive_tests.sh`
- **Writing tests**: See templates in `tests/modules/` and `tests/scripts/`
- **CI/CD issues**: Contact development team

## 🔄 Test Maintenance

### Adding New Tests

1. Identify untested modules/scripts:
```bash
./tests/run_comprehensive_tests.sh | grep "Coverage:"
```

2. Use templates to create tests
3. Run tests locally
4. Commit with tests
5. Verify CI passes

### Updating Existing Tests

When modifying code:
1. Run affected tests first
2. Update tests if behavior changes
3. Ensure coverage doesn't drop
4. Document breaking changes

## 🎓 Resources

- **NixOS VM Tests**: https://nixos.org/manual/nixos/stable/#sec-nixos-tests
- **BATS Testing**: https://github.com/bats-core/bats-core
- **Test Helpers**: `tests/lib/test_helpers.bash`
- **Templates**: `tests/modules/test_template.nix`, `tests/scripts/test_script_template.bats`

---

**Hyper-NixOS** - Next-Generation Virtualization Platform

© 2024-2025 MasterofNull | Licensed under the MIT License

Project: https://github.com/MasterofNull/Hyper-NixOS
