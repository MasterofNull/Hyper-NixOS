# Hyper-NixOS System Completion Roadmap

Generated: 2026-03-21
Target Version: 2.2.0
Status: Execution In Progress - Tests And CI Green

## Overview

This roadmap replaces the earlier assumption-only plan with a validated baseline from the current repository and the local AI harness. The repo is on `main`, the worktree is dirty, and several plan assumptions from the earlier draft were stale.

## Validated Baseline

Validation run on 2026-03-21:

- `nix flake check --no-build` fails.
- `bash tests/run_all_tests.sh` passes 5/5.
- `bash tests/ci_validation.sh` passes.
- `aq-qa 0 --json` reports the harness mostly healthy, but with 2 failures:
  - `ai-gap-import.service` is failed
  - `continue-local switchboard smoke` is failed

## Current State Summary

| Component | Status | Blocking? | Notes |
|-----------|--------|-----------|-------|
| Flake Build | BROKEN | Yes - P0 | Progressed past multiple module issues; currently blocked by remaining flake evaluation errors |
| Test Suite | PASS | No | `bash tests/run_all_tests.sh` passes 5/5 |
| CI Validation | PASS | No | `bash tests/ci_validation.sh` passes cleanly |
| AI Harness | PARTIAL | No - P1 | Health OK, but helper CLI drift and 2 QA failures need cleanup |
| TODOs | 17 Items | No - P2 | Inventory validated with `rg` |
| Worktree | DIRTY | Yes - Operational | Existing user changes must be preserved while executing fixes |

## Phase Overview

| Phase | Name | Priority | Effort | Dependencies | Current Reality |
|-------|------|----------|--------|--------------|-----------------|
| 01 | Flake Evaluation Fix | P0 | Medium | None | In progress; remaining blocker is on the flake evaluation path |
| 02 | Test Fixes | P1 | Small | Phase 01 helpful, not strictly required | Complete |
| 03 | CI Fixes | P1 | Small | None | Complete |
| 04 | AI Layer Stabilization | P1 | Medium | None | Use authenticated harness endpoints; document helper drift and failures |
| 05 | TODO Resolution | P2 | Medium | Phases 01-03 | Refresh and resolve validated 17-item TODO inventory |

## Execution Order

```text
Phase 01: Fix flake evaluation blocker
  -> restores high-signal Nix validation

Phase 02: Fix failing tests
Phase 03: Fix CI validation gap
  -> can run in parallel once local edits are understood

Phase 04: Stabilize AI layer + continuity workflow
  -> keep harness usable for follow-on slices

Phase 05: Resolve validated TODO inventory
  -> only after baseline gates are green
```

## Immediate Next Slices

### Slice A: Re-baseline flake blocker
1. Trace where `hypervisor.system.architecture` and `hypervisor.system.platform` are set.
2. Identify whether the option definition was removed, renamed, or should be created.
3. Make the minimal compatible fix.
4. Re-run `nix flake check --no-build`.

### Slice B: Preserve Completed Validation Wins
1. Keep test-suite fixes intact.
2. Keep CI compatibility entrypoints intact.
3. Re-run `bash tests/run_all_tests.sh` and `bash tests/ci_validation.sh` after major Nix changes.

### Slice D: Normalize AI harness usage for this repo
1. Use `aq-qa 0 --json` as the first health gate.
2. Use authenticated calls to:
   - `GET /hints`
   - `GET /workflow/plan?q=...`
   - `POST /memory/recall`
   - `POST /memory/store`
3. Record validated project state in harness memory after each phase.
4. Treat `aq-context-bootstrap` as unavailable on this host until installed.

## Detailed Plan Links

- [Phase 01: Flake Evaluation Fix](./phase-01-build-fix.md)
- [Phase 02: Test Fixes](./phase-02-test-fixes.md)
- [Phase 03: CI Fixes](./phase-03-ci-fixes.md)
- [Phase 04: AI Layer Stabilization](./phase-04-ai-layer.md)
- [Phase 05: TODO Resolution](./phase-05-todo-resolution.md)

## Operational Constraints

1. Preserve unrelated user changes in the dirty worktree.
2. Prefer module fixes over imperative workarounds.
3. Capture validation evidence after each slice.
4. Use the local AI harness for discovery, hints, workflow planning, and continuity memory.

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| `nix flake check --no-build` | FAIL | PASS |
| `bash tests/run_all_tests.sh` | PASS | PASS |
| `bash tests/ci_validation.sh` | PASS | PASS |
| `aq-qa 0 --json` | 34 pass / 2 fail | clean or documented accepted failures |
| TODO count (`rg -n "TODO" tests modules scripts --glob '*.nix' --glob '*.sh'`) | 17 | 0 or explicitly deferred |

## Communication / Continuity

After each completed phase:

1. Update the corresponding phase plan status.
2. Update this roadmap status and current-state table if reality changes.
3. Store a concise harness memory entry with:
   - completed slice
   - validations run
   - remaining blockers
   - rollback notes
