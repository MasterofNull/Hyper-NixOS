# GitHub Actions CI/CD Guide for Hyper-NixOS

## Table of Contents
1. [Overview](#overview)
2. [What is GitHub Actions?](#what-is-github-actions)
3. [Our CI Pipeline Structure](#our-ci-pipeline-structure)
4. [Test Jobs Explained](#test-jobs-explained)
5. [How CI Tests Work](#how-ci-tests-work)
6. [Setting Up GitHub Actions](#setting-up-github-actions)
7. [Common Issues and Solutions](#common-issues-and-solutions)
8. [Best Practices](#best-practices)
9. [Advanced Topics](#advanced-topics)

## Overview

GitHub Actions is our Continuous Integration/Continuous Deployment (CI/CD) system that automatically runs tests whenever code is pushed or pull requests are created. This ensures code quality, catches bugs early, and maintains project standards.

## What is GitHub Actions?

GitHub Actions is a CI/CD platform that allows you to automate your build, test, and deployment pipeline. Key concepts:

- **Workflows**: Automated processes defined in YAML files
- **Jobs**: Sets of steps that execute on the same runner
- **Steps**: Individual tasks that can run commands or actions
- **Runners**: Virtual machines that execute your jobs
- **Events**: Triggers that start workflows (push, pull request, etc.)

## Our CI Pipeline Structure

Our main workflow file is located at `.github/workflows/test.yml`. Here's what it does:

```yaml
name: Test & Quality Assurance

on:
  push:
    branches: [ main, develop, cursor/* ]
  pull_request:
    branches: [ main ]
```

This triggers on:
- Any push to main, develop, or cursor/* branches
- Any pull request targeting the main branch

## Test Jobs Explained

### 1. Shellcheck & Linting (`shellcheck`)

**Purpose**: Checks shell scripts for common errors and style issues

**What it does**:
- Installs shellcheck linting tool
- Scans all `.sh` files in the scripts directory
- Reports warnings and errors (warnings are informational only)
- Excludes certain checks that are too strict for our use case

**Example issues it catches**:
```bash
# Bad: Unquoted variable
echo $var

# Good: Quoted variable
echo "$var"

# Bad: Missing error handling
cd /some/dir
rm -rf *

# Good: Error handling
cd /some/dir || exit 1
rm -rf ./*
```

### 2. Syntax Validation (`syntax`)

**Purpose**: Ensures all bash scripts have valid syntax

**What it does**:
- Uses `bash -n` to check syntax without executing
- Validates every `.sh` file can be parsed
- Fails if any syntax errors are found

**Example issues it catches**:
```bash
# Syntax error: Missing closing quote
echo "Hello world

# Syntax error: Invalid if statement
if [ $x -eq 1 ] then
  echo "x is 1"
fi
```

### 3. Validate Project Structure (`validate-structure`)

**Purpose**: Ensures all required files exist

**What it does**:
- Checks for essential project files
- Verifies documentation is present
- Ensures critical scripts exist

**Files it checks**:
- README.md
- configuration.nix
- Core scripts (installer, menu, etc.)
- Documentation files

### 4. Integration Tests (`test-integration`)

**Purpose**: Runs our test suite

**What it does**:
- Makes test scripts executable
- Validates test script syntax
- Runs `tests/run_all_tests.sh` in CI mode
- Skips tests requiring NixOS/libvirt (expected in CI)

**CI Mode Behavior**:
- Sets `CI=true` environment variable
- Skips tests that need system-level features
- Focuses on unit tests and basic validation

### 5. Security Scanning (`security`)

**Purpose**: Checks for security issues

**What it does**:
- Scans for hardcoded secrets/passwords
- Checks file permissions (no world-writable files)
- Provides security summary

**Patterns it looks for**:
```bash
# Bad: Hardcoded password
DB_PASSWORD="actualPassword123"

# OK: Placeholder
DB_PASSWORD="CHANGEME"

# OK: Variable reference
DB_PASSWORD="$DB_PASS_FROM_ENV"
```

### 6. Build & Package (`build`)

**Purpose**: Creates release packages (only on version tags)

**What it does**:
- Triggers only on version tags (e.g., `v1.0.0`)
- Creates tarball of the project
- Generates SHA256 checksums
- Creates GitHub release with artifacts

## How CI Tests Work

### Environment

Tests run on Ubuntu runners with:
- Basic Linux utilities
- Git
- Bash
- Ability to install packages via apt

### Test Flow

1. **Checkout**: Gets the latest code
2. **Setup**: Installs required tools
3. **Execute**: Runs the specific test
4. **Report**: Shows results and uploads artifacts

### CI Detection

Tests detect CI environment via:
```bash
if [[ "${CI:-false}" == "true" ]] || [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
    # Running in CI
fi
```

## Setting Up GitHub Actions

### For Your Fork/Repository

1. **Enable Actions**:
   - Go to Settings → Actions
   - Select "Allow all actions and reusable workflows"

2. **Create Workflow**:
   ```bash
   mkdir -p .github/workflows
   cp test.yml .github/workflows/
   ```

3. **Commit and Push**:
   ```bash
   git add .github/workflows/test.yml
   git commit -m "Add CI workflow"
   git push
   ```

### Customizing Tests

To modify test behavior:

1. **Add New Test Job**:
   ```yaml
   my-custom-test:
     name: My Custom Test
     runs-on: ubuntu-latest
     steps:
       - uses: actions/checkout@v4
       - name: Run my test
         run: |
           echo "Running custom test"
           ./my-test-script.sh
   ```

2. **Change Triggers**:
   ```yaml
   on:
     push:
       branches: [ main, feature/* ]
     schedule:
       - cron: '0 0 * * 0'  # Weekly
   ```

3. **Add Dependencies**:
   ```yaml
   - name: Install tools
     run: |
       sudo apt-get update
       sudo apt-get install -y tool1 tool2
   ```

## Common Issues and Solutions

### Issue: Tests Failing in CI but Passing Locally

**Cause**: CI environment lacks system dependencies

**Solution**: 
- Check for CI mode in tests
- Mock or skip system-dependent tests
- Install required tools in workflow

**Example**:
```bash
# In test script
if [[ "${CI:-false}" == "true" ]]; then
    echo "Skipping libvirt test in CI"
    exit 0
fi
```

### Issue: Permission Denied Errors

**Cause**: Scripts not marked executable

**Solution**:
```yaml
- name: Make scripts executable
  run: chmod +x scripts/*.sh
```

### Issue: Shellcheck Warnings

**Cause**: Shell scripts don't follow best practices

**Solution**: Fix the warnings or exclude if intentional:
```yaml
shellcheck --exclude=SC2086  # Exclude specific warning
```

### Issue: Hardcoded Secrets Detection

**Cause**: Real or example passwords in code

**Solution**:
- Use environment variables
- Use placeholder values (CHANGEME)
- Store secrets in GitHub Secrets

## Best Practices

### 1. Write CI-Friendly Tests

```bash
#!/usr/bin/env bash
# Good: Detects and handles CI environment

if [[ "${CI:-false}" == "true" ]]; then
    echo "Running in CI mode"
    # Adjust behavior for CI
fi

# Bad: Assumes full system access
systemctl restart libvirtd  # Will fail in CI
```

### 2. Use Meaningful Test Names

```yaml
# Good: Descriptive name
- name: Validate configuration file syntax

# Bad: Generic name  
- name: Test 1
```

### 3. Fail Fast

```yaml
# Good: Exit on first error
set -euo pipefail

# Bad: Continue on errors
set +e
```

### 4. Provide Useful Output

```bash
# Good: Clear error messages
if [[ ! -f "$config_file" ]]; then
    echo "ERROR: Configuration file not found: $config_file"
    echo "Expected location: /etc/hypervisor/config.json"
    exit 1
fi

# Bad: Silent failure
[[ -f "$config_file" ]] || exit 1
```

### 5. Cache Dependencies

```yaml
# Cache apt packages
- uses: actions/cache@v3
  with:
    path: /var/cache/apt
    key: ${{ runner.os }}-apt-${{ hashFiles('**/package-list.txt') }}
```

## Advanced Topics

### Matrix Testing

Test across multiple versions/configurations:

```yaml
strategy:
  matrix:
    os: [ubuntu-20.04, ubuntu-22.04]
    bash-version: [4.4, 5.0, 5.1]
runs-on: ${{ matrix.os }}
steps:
  - name: Test with Bash ${{ matrix.bash-version }}
    run: |
      bash --version
      ./run-tests.sh
```

### Conditional Jobs

Run jobs based on conditions:

```yaml
release:
  if: startsWith(github.ref, 'refs/tags/v')
  runs-on: ubuntu-latest
  steps:
    - name: Create release
      run: ./create-release.sh
```

### Secrets Management

Use GitHub Secrets for sensitive data:

```yaml
- name: Deploy
  env:
    API_KEY: ${{ secrets.API_KEY }}
  run: |
    ./deploy.sh
```

### Artifacts

Save test results:

```yaml
- name: Upload test results
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: test-results
    path: |
      test-reports/
      *.log
```

### Status Badges

Add to README.md:

```markdown
![CI Status](https://github.com/USER/REPO/workflows/Test%20&%20Quality%20Assurance/badge.svg)
```

## Debugging CI Failures

### 1. Check Workflow Logs

- Click on the failed job in GitHub
- Expand failed steps
- Look for error messages

### 2. Run Locally with CI Environment

```bash
# Simulate CI environment
export CI=true
export GITHUB_ACTIONS=true
./tests/run_all_tests.sh
```

### 3. Add Debug Output

```yaml
- name: Debug environment
  run: |
    echo "Current directory: $(pwd)"
    echo "Files present:"
    ls -la
    echo "Environment:"
    env | sort
```

### 4. Use act for Local Testing

Install [act](https://github.com/nektos/act) to run GitHub Actions locally:

```bash
# Install act
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Run workflows locally
act push
act pull_request
```

## CI Test File Reference

### Main Workflow: `.github/workflows/test.yml`

- **Location**: `.github/workflows/test.yml`
- **Purpose**: Defines all CI jobs and their steps
- **Triggers**: Push and pull request events
- **Jobs**: shellcheck, syntax, validate-structure, test-integration, security, build

### Test Runner: `tests/run_all_tests.sh`

- **Purpose**: Executes all tests with CI awareness
- **Features**:
  - Detects CI environment
  - Skips system-dependent tests in CI
  - Provides summary of results
  - Returns appropriate exit codes

### Unit Tests: `tests/unit/`

- **Purpose**: Test individual functions and components
- **Examples**:
  - `test_common.sh`: Tests common library functions
  - `test_common_ci.sh`: CI-friendly version

### Integration Tests: `tests/integration/`

- **Purpose**: Test system-wide functionality
- **Note**: Most skip in CI due to system requirements

## Summary

GitHub Actions CI provides:
- Automated quality checks on every commit
- Early detection of bugs and issues
- Consistent code standards enforcement
- Security scanning
- Automated releases

Key points:
- Tests run automatically on push/PR
- CI environment is limited (no systemd, libvirt, etc.)
- Write tests with CI limitations in mind
- Use CI detection to adjust test behavior
- Failed CI checks block PR merging (protects main branch)

By following this guide, you can understand, modify, and extend our CI pipeline to maintain high code quality and catch issues before they reach production.