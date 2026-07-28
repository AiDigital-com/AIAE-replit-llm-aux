# Agent surface lifecycle: dual native discovery

## Decision

An active generated project carries two skill registries:

- `.agents/skills/` for Replit Agent discovery;
- `.claude/skills/` for Claude Code discovery.

They are generated from the same pinned common source and carry provenance.
Project-owned portable workflows are maintained as matching copies. This is not
a preference for duplication: both locations are native runtime contracts.

## Shared state and rules

Both rendered `task-workflow` copies use `.claude/tasks`. Shared engineering
rules remain under `.claude/rules` and `.claude/agent_docs`; Replit instructions
explicitly direct its workflows to those authoritative documents. No
`.agents/rules` tree is created.

## Lifecycle

Materialization and release create an **active dual-agent project** containing
`AGENTS.md`, `replit.md`, `.agents/skills`, `CLAUDE.md`, `.claude/skills`,
`.claude/rules`, `.claude/agent_docs`, and `.claude/tasks/README.md`.

Engineering handoff is a distinct, opt-in cleanup. It removes `AGENTS.md`,
`replit.md`, `.agents`, `custom_instruction`, and `templates`, while preserving
the Claude engineering surface. It must never be conflated with normal
materialization.
