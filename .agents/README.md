# .agents

Progressive-disclosure planning artifacts for TBD.

- Keep plans in `.agents/plans/`.
- Keep always-read files small and link to deep docs.
- Prefer one slice per plan file.

## Structure Contract
- `.agents/` stores planning artifacts only.
- `.claude/commands/` stores command specs (not plans).
- `.agent/` stores PRD/global rules/workflow state (not plans).

## Layout
```text
.agents/
└── plans/
    ├── README.md
    ├── phase-template.md
    └── phase-XX-*.md
```
