# CLAUDE.md

This file provides guidance to Claude Code when working in the Hyper-NixOS repository.

## Project Overview

Project: Hyper-NixOS
Goal: Production-ready NixOS-based hypervisor with AI-driven monitoring, mesh clustering, and zero-trust security
Owner: MasterofNull
Stack: NixOS 25.05, Go (GraphQL API), Python (AI monitoring), Bash (CLI tools)

## Commands

```bash
/prime
/create-prd .agent/PROJECT-PRD.md
/plan-feature "objective"
/execute .agents/plans/phase-template.md
/commit
/explore-harness
```

## Project Structure

```text
repo/
├── .agent/
│   ├── PROJECT-PRD.md
│   ├── GLOBAL-RULES.md
│   └── workflows/
├── .claude/
│   └── commands/
└── .agents/
    └── plans/
```

## File Placement Contract

1. PRD/rules/workflow evidence belong in `.agent/`.
2. Slash-command behavior files belong in `.claude/commands/`.
3. Phase/slice plans belong in `.agents/plans/`.
4. Do not create workflow artifacts in repo root.
5. Validate with `repo-structure-lint` before commit.

## Delegation + Role Defaults

- Default mode: orchestrator/reviewer first, direct implementation second.
- Routing:
  - `codex`: orchestrator + reviewer gate.
  - `claude`: architecture/risk/policy synthesis slices.
  - `qwen`: implementation/test slices.
- Sub-agent non-orchestrator rule:
  - sub-agents execute only assigned slices,
  - do not re-scope goals,
  - do not route other agents,
  - do not finalize acceptance.

## Tool-First Approach

**Always use tools first** for:
- discovery and codebase analysis (grep, glob patterns, file reads)
- executing workflows (aqd commands, shell scripts)
- validation and testing (test runners, linters, build commands)

Use direct implementation only after:
- problem scope is clear from tool output
- validation plan is documented
- AI-layer guidance is understood

## Validation Commands

**Primary validation gates (run these frequently):**
```bash
# Flake evaluation check (fast, no build)
nix flake check --no-build

# Test suite (5 tests)
bash tests/run_all_tests.sh

# CI validation (153 checks)
bash tests/ci_validation.sh

# Git status
git status --short
```

**Current project status (as of 2026-03-21):**
- All 5 phases complete
- All validations passing
- TODO count: 0
- Ready for feature development

## AI Harness Integration

This project uses the local AI harness (Hybrid Coordinator on port 8003, AIDB on port 8002).

**Health check:**
```bash
aq-qa 0 --json
```

**Authenticated endpoints (use API key from /run/secrets/hybrid_coordinator_api_key):**
- `GET /hints` - Context-aware suggestions
- `GET /workflow/plan?q=...` - Workflow planning
- `POST /memory/recall` - Retrieve stored context
- `POST /memory/store` - Store project state

## On-Demand Context

| Topic | File |
|-------|------|
| PRD | `.agent/PROJECT-PRD.md` |
| Rules | `.agent/GLOBAL-RULES.md` |
| Plans | `.agents/plans/` |
| Roadmap | `.agents/plans/ROADMAP.md` |
| Workflow evidence | `.agent/workflows/` |
