# Agent entry point

This repository is a **Replit Custom Template control plane**, not a runnable app.

## Start here

1. **Rules:** `custom_instruction/instructions.md` (always authoritative).
2. **Context:** `replit.md` (project preferences and deployment model).
3. **Scaffold:** copy from `templates/generated-project/scaffold/` — never regenerate from Spring Initializr or `npm create vite`.
4. **Package naming:** run `bash scripts/apply-package-name.sh <app-name-package>` after copying the scaffold.
5. **Workflows:** Replit discovers skills from `.agents/skills/*/SKILL.md`; do not duplicate canonical docs inline.
6. **Project shape:** read `templates/generated-project/generation/project-shape-decision.md` before deciding frontend-only vs full-stack.
7. **HTML-only inputs:** if logging, persistence, auth, or multi-user review is needed, migrate to the generated `frontend/` + Java `backend/` layout; do not keep a static-only app.

## Decision ownership

The user owns business goals, priorities, and acceptance—not technical design.
Do not ask them to choose frameworks, architecture, persistence, API, caching,
or test mechanisms. Resolve technical ambiguity with the strongest available
reasoning role and record the rationale. Ask only for missing business behavior,
credentials/access, or an irreversible product decision, phrased in business
terms. Follow `.claude/agent_docs/agent-operating-model.md` for role routing and
the fresh final-review loop. Keep user-visible work locally demonstrable; when
the user asks to see it, invoke `local-preview` and supply safe local fixtures
when the flow otherwise has no useful data.

## Dual runtime surfaces

Replit Agent and Claude Code have different native skill discovery paths.
Common skills are generated from one pinned source and synchronized to both;
never edit generated copies directly. The two copies intentionally share
`.claude/tasks`, so plan/review/verification artifacts remain interoperable.

| Path | Holds | Who reads it |
|---|---|---|
| `.agents/skills/` | Replit-discovered on-demand workflows | Replit Agent |
| `.claude/skills/` | Claude Code on-demand workflows | Claude Code |
| `.claude/rules/` | authoritative project rules | every agent |
| `.claude/agent_docs/` | background documentation | every agent |
| `.claude/tasks/` | task artifacts (plan, review, verification) | every agent |
| `AGENTS.md`, `replit.md` | Replit entry points | Replit Agent |
| `CLAUDE.md` | Claude Code entry point | Claude Code |

Skills listed in `agent-payload.skills` ship into generated projects in both
registries. Common generated skills reference only installed project files.
Project-owned skills cite canonical `templates/generated-project/**` sources
while running in this control plane; materialization rewrites those citations
to installed `.claude/agent_docs/**` paths. `project-init` remains
Claude/template-control-plane only.

`scripts/check-payload-portability.sh` enforces that split in CI.

## Canonical artifacts

All topic-specific rules live under `templates/generated-project/`. See the authoritative-references table in `custom_instruction/instructions.md`.
