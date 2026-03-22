# Phase 01: Flake Evaluation Fix

**Priority**: P0 - Blocking
**Status**: Ready for Execution
**Estimated Effort**: Small

## Objective
Restore `nix flake check --no-build` by fixing the current NixOS module evaluation failure.

## Scope Lock
- **In scope**: Minimal fix for the current flake evaluation blocker
- **Out of scope**: New features, broad module refactors
- **Constraints**: Must maintain backwards compatibility with NixOS 24.05+

## Context References
- Files to read first:
  - `flake.nix`
  - `configuration.nix`
  - `modules/core/arm-detection.nix`
  - any module defining or replacing `hypervisor.system.*`
- Docs to read first:
  - NixOS flake patterns: https://nixos.wiki/wiki/Flakes

## Current Error
```
error: The option `hypervisor.system' does not exist.
```

## Root Cause Analysis
The old ISO derivation bug is already patched in `flake.nix`.

The current blocker is a module-option mismatch:
- `modules/core/arm-detection.nix` writes `hypervisor.system.architecture`
- `modules/core/arm-detection.nix` writes `hypervisor.system.platform`
- no matching `options.hypervisor.system` definition is currently available during evaluation

This phase should determine whether:
1. the option definition was removed accidentally,
2. the writer should target a newer option namespace, or
3. a compatibility option layer is required.

## Steps

### Slice 1.1: Trace Option Ownership
1. Search for all `hypervisor.system` references and related option namespaces.
2. Identify the intended owner module for architecture/platform metadata.
3. Confirm whether the fix belongs in `arm-detection.nix`, a shared options module, or both.

### Slice 1.2: Apply Minimal Compatibility Fix
1. Implement the smallest change that restores evaluation.
2. Avoid broad restructuring while the worktree is dirty.
3. Re-run `nix flake check --no-build`.

### Slice 1.3: Validate Build Path
1. Run `nix build .#iso --dry-run`.
2. If evaluation succeeds, note any next error discovered.
3. Update roadmap status with the new blocker or mark this phase complete.

## Validation
- **Syntax**: `nix flake check --no-build`
- **Tests**: `nix build .#iso --dry-run`
- **Smoke**: flake evaluates without `hypervisor.system` option failure

## Evidence
- Files changed: likely `modules/core/arm-detection.nix` and/or shared options modules
- Commands run: `nix flake check --no-build`, `nix build .#iso --dry-run`
- Output snippets: (to be captured)

## Commit Message Template
```
fix(nix): restore flake evaluation for hypervisor system metadata

Restores module evaluation by reconciling the hypervisor.system
metadata writer with the available option namespace.

Fixes flake error: "The option `hypervisor.system' does not exist"
```

## Rollback
- `git checkout -- <changed-files>`
- Restore from backup commit
