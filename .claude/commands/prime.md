---
description: Prime agent with project context using progressive disclosure
---

# Prime: Load Project Context

## Step 1: Fetch AI Stack Hints (if available)

```bash
# Get contextual hints for current objective
aq-hints --query "TBD" --format json 2>/dev/null || true
```

## Step 2: Inspect Structure

- Run `git ls-files | head -50` for file overview
- Check top-level directories

## Step 3: Load Core Artifacts (progressive disclosure)

Read only essential files:
- `.agent/PROJECT-PRD.md`
- `.agent/GLOBAL-RULES.md`
- Latest `.agent/workflows/*`
- Latest `.agents/plans/*`

## Step 4: Check State

- `git status` for pending changes
- Recent commits for context

## Step 5: Tool Discovery

Query available tools:
```bash
curl -sf http://localhost:8003/discovery/capabilities?level=overview 2>/dev/null | jq -r '.capabilities' || echo "Harness offline"
```

## Step 6: Summarize

Output:
- Current project state
- Active/pending tasks
- Suggested next slice
- Available tools (if harness online)
