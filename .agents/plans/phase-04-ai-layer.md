# Phase 04: AI Layer Stabilization

**Priority**: P2 - Medium
**Status**: Complete
**Estimated Effort**: Medium
**Dependencies**: Phases 01-03 complete

## Objective
Normalize and document the repo's AI-assisted workflow against the live local harness.

## Scope Lock
- **In scope**:
  - Validate `.claude/` and `.agent/` artifacts against the current repo
  - Use the local AI harness for discovery, planning, and memory
  - Document the actual authenticated workflow for this host
- **Out of scope**: New AI platform features, model training
- **Constraints**: Follow existing AI layer conventions from NixOS-Dev-Quick-Deploy

## Context References
- Files to read first:
  - `.claude/CLAUDE.md`
  - `.agent/PROJECT-PRD.md`
  - `/home/hyperd/.claude/settings.json` (MCP config)
- Docs to read first:
  - MCP bridge: `/opt/nixos-quick-deploy/scripts/ai/mcp-bridge-hybrid.py`

## Current State
- `.claude/CLAUDE.md` exists and is partially populated
- `.agent/PROJECT-PRD.md`, `.agent/GLOBAL-RULES.md`, and brownfield workflow evidence exist
- `aq-qa 0 --json` succeeds overall but reports 2 failures:
  - `ai-gap-import.service` failed
  - `continue-local switchboard smoke` failed
- `aq-context-bootstrap` is not installed on this host
- Authenticated `curl` calls with `/run/secrets/hybrid_coordinator_api_key` work for:
  - `/discovery/capabilities`
  - `/hints`
  - `/workflow/plan?q=...`
  - `/memory/recall`

## Steps

### Slice 4.1: Lock the Actual Harness Access Pattern
1. Document the authenticated endpoint usage pattern for this repo.
2. Record unavailable helper commands so future agents do not assume they exist.
3. Keep `aq-qa 0 --json` as the first harness health gate.

### Slice 4.2: Validate Repo AI Artifacts
1. Reconcile `.claude/CLAUDE.md` with the current folder contract.
2. Confirm `.agent/PROJECT-PRD.md` and `.agent/GLOBAL-RULES.md` reflect real repo state.
3. Remove stale assumptions from AI-layer docs as they are discovered.

### Slice 4.3: Store Continuity in Harness Memory
1. Recall prior Hyper-NixOS planning memory before large slices.
2. Store updated project state after each completed phase.
3. Keep summaries concise and validation-driven.

### Slice 4.4: Triage Harness QA Drift
1. Capture the two current `aq-qa 0` failures in roadmap continuity.
2. Decide later whether they block development, or remain accepted harness debt.

## Validation
- **Syntax**: YAML/Markdown lint
- **Tests**: authenticated `curl` calls return valid JSON
- **Smoke**: hints, workflow plan, and memory recall/store all work from this repo

## Evidence
- Files changed: AI-layer docs as needed
- Commands run: `aq-qa 0 --json`, authenticated harness endpoint calls
- Output snippets: Successful query responses

## Commit Message Template
```
docs(ai): align Hyper-NixOS workflow with live local harness

- Documented authenticated harness usage
- Removed stale workflow assumptions
- Captured continuity workflow for future slices
```

## Rollback
- `git checkout .claude/ .agent/`
