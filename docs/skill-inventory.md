# Skill Inventory — Pre-Split Baseline (historical)

> **Historical document.** It describes the two-registry layout
> (`.agents/skills/` + `.claude/skills/`) that existed before the split, and its
> dual-target conclusions were temporarily replaced by a one-registry design.
> That design was rejected: active projects use both native discovery paths.
> See `agents-lifecycle-decision.md` and `../agent-payload.skills`.
>
> Kept for the per-skill ownership and divergence analysis, which is still the
> record of why each skill landed where it did.

Status: **approved for execution** (solo owner; no external approval gate).
Source repo: `ai-digital-replit-llm-aux` (commit at split time).
Date: 2026-07-22.

This document records every skill found in `.agents/skills/` and `.claude/skills/`
before the split into `AIAE-llm-aux` (common) and `AIAE-replit-llm-aux`
(project). It fixes ownership and migration action for each skill so no skill
is moved by assumption.

## Classification legend

| Class | Meaning |
|---|---|
| `common-identical` | Byte-identical on both targets; one canonical copy in `AIAE-llm-aux`, rendered to both. |
| `common-with-placeholder` | Same body; only `{{TASK_STATE_DIR}}` differs; canonical as `SKILL.md.template`. |
| `common-needs-normalization` | Common skill but directory/frontmatter mismatch or invalid frontmatter; fix before move. |
| `new-generic-skill-required` | No generic version exists; author new in `AIAE-llm-aux`; keep concrete versions project-side. |
| `Replit-specific` | Tied to Replit template generation; stays in `AIAE-replit-llm-aux`. |
| `Claude/project-specific` | Concrete compliance review tied to installed project rules; stays project-side. |
| `freshly-authored-needs-validation` | Authored immediately before split; canonical but flagged for real-world validation. |

No skill is classified `unclear`. No skill is classified `deprecated`.

## `.agents/skills/` (11 skills)

| # | Directory | `name:` | Class | Canonical owner | Migration action |
|---|---|---|---|---|---|
| 1 | `backend-java-feature` | `backend-java-feature` | Replit-specific | AIAE-replit | Keep. Generation-time workflow for the template backend. |
| 2 | `backend-rule-review` | `backend-rule-review` | Claude/project-specific | AIAE-replit | Keep as project compliance skill. Differs from `.claude` version (different rule sources). |
| 3 | `engineering-handoff` | `engineering-handoff` | Replit-specific | AIAE-replit | Keep. MVP→engineering handoff; will be updated to call `prepare-engineering-handoff.sh`. |
| 4 | `frontend-react-feature` | `frontend-react-feature` | Replit-specific | AIAE-replit | Keep. Generation-time workflow for the template frontend. |
| 5 | `frontend-style-review` | `frontend-style-review` | Claude/project-specific | AIAE-replit | Keep as project frontend review. Differs from `.claude` version. |
| 6 | `mvp-safety-review` | `mvp-safety-review` | Replit-specific | AIAE-replit | Keep. Replit pre-publish gate. **Publish-gate line 61 must be reconciled with Variant B** (see `docs/agents-lifecycle-decision.md`). |
| 7 | `openapi-contract-first` | `openapi-contract-first` | Replit-specific | AIAE-replit | Keep. Contains Replit paths, Clerk, concrete Maven module structure. Generic contract-first sequence may be extracted to common later; out of scope for initial split. |
| 8 | `aiae-rule-compliance-audit` | `aiae-rule-compliance-audit` | Claude/project-specific (concrete) | AIAE-replit | Keep concrete `.agents` version. Generic framework authored separately in `AIAE-llm-aux`. |
| 9 | `task-workflow` | `task-workflow` | common-with-placeholder | AIAE-llm-aux | Move as `SKILL.md.template`. Refactor: `{{TASK_STATE_DIR}}`, remove auto `git add`, remove duplicated stack rules, add `mode: plan|execute|autonomous`, remove mandatory `Positive Observations`. |
| 10 | `ui-designer` | `ui-designer` | Claude/project-specific | AIAE-replit | Keep project-owned: it relies on this template's installed visual-system docs. |
| 11 | `verification-gate` | `verification-gate` | common-identical | AIAE-llm-aux | Move. Byte-identical on both targets. Keep vendor-neutral; `/verify` optional only. |

## `.claude/skills/` (8 skills)

| # | Directory | `name:` | Class | Canonical owner | Migration action |
|---|---|---|---|---|---|
| 1 | `backend-rule-review` | `backend-rule-review` | Claude/project-specific | AIAE-replit | Keep as project compliance skill. Differs from `.agents` version (reads `.claude/rules/...` not `templates/generated-project/...`). |
| 2 | `code-review` | `production-code-review` | common-needs-normalization | AIAE-llm-aux | **Rename dir `code-review`→`production-code-review`** (frontmatter already correct), then move to common. |
| 3 | `frontend-style-review` | `frontend-style-review` | Claude/project-specific | AIAE-replit | Keep as project frontend review. Differs from `.agents` version. |
| 4 | `performance-review` | `fullstack-performance-audit` | common-needs-normalization + freshly-authored-needs-validation | AIAE-llm-aux | **Rename dir `performance-review`→`fullstack-performance-audit`**, **fix invalid frontmatter closing delimiter** (long hyphen line instead of `---`), review body, then move to common. Mark `status: needs real-world validation` in CHANGELOG. |
| 5 | `aiae-rule-compliance-audit` | `aiae-rule-compliance-audit` | Claude/project-specific (concrete) | AIAE-replit | Keep concrete `.claude` version. Generic framework authored separately in `AIAE-llm-aux`. |
| 6 | `task-workflow` | `task-workflow` | common-with-placeholder | AIAE-llm-aux | Move as `SKILL.md.template` (same refactor as `.agents` version). |
| 7 | `ui-designer` | `ui-designer` | Claude/project-specific | AIAE-replit | Keep project-owned: visual-system-specific. |
| 8 | `verification-gate` | `verification-gate` | common-identical | AIAE-llm-aux | Move. Byte-identical. |

## Cross-target divergence summary

| Skill | `.agents` vs `.claude` | Reason |
|---|---|---|
| `verification-gate` | identical | — |
| `ui-designer` | identical | Project-owned despite matching copies: it depends on AIAE visual-system docs. |
| `task-workflow` | 8 path substitutions | `.agents/tasks` vs `.claude/tasks` |
| `backend-rule-review` | strongly divergent | `.agents` reads `templates/generated-project/...`; `.claude` reads `.claude/rules/...`. Different rule sources, different scope wording. |
| `frontend-style-review` | divergent | `.agents` reads `AGENTS.md` + `templates/...`; `.claude` reads `CLAUDE.md` + `.claude/rules/40-frontend-rules.md`. Scanner patterns differ. |
| `rule-compliance-audit` | strongly divergent | Same pattern as `backend-rule-review`: template rule files vs installed project rules. |

## Skills moving to `AIAE-llm-aux` (5 common)

1. `verification-gate` — `skills/verification-gate/SKILL.md`
2. `production-code-review` — `skills/production-code-review/SKILL.md` (after rename from `code-review`)
3. `fullstack-performance-audit` — `skills/fullstack-performance-audit/SKILL.md` (after rename + frontmatter fix; flagged needs-validation)
4. `task-workflow` — `skills/task-workflow/SKILL.md.template` (refactored)
5. `rule-compliance-audit` — `skills/rule-compliance-audit/SKILL.md` (newly authored generic framework)

## Skills staying in `AIAE-replit-llm-aux` (8 project + concrete)

- `.agents/skills/`: `backend-java-feature`, `frontend-react-feature`, `mvp-safety-review`, `engineering-handoff`, `openapi-contract-first`, `backend-rule-review`, `frontend-style-review`, `rule-compliance-audit` (concrete).
- `.claude/skills/`: `backend-rule-review`, `frontend-style-review`, `rule-compliance-audit` (concrete).

The common skills (`verification-gate`, `production-code-review`,
`fullstack-performance-audit`, `task-workflow`, generic `rule-compliance-audit`)
will be **generated** into both `.agents/skills/` and `.claude/skills/` of the
Replit repo by `sync-llm-aux.sh`, with provenance headers, and committed.

## Pre-existing issues to fix before/during move

1. `.claude/skills/code-review/` directory name ≠ frontmatter `name: production-code-review`. Rename directory.
2. `.claude/skills/performance-review/` directory name ≠ frontmatter `name: fullstack-performance-audit`. Rename directory.
3. `.claude/skills/performance-review/SKILL.md` frontmatter closing delimiter is a long hyphen line, not `---`. YAML is unparseable. Fix delimiter.
4. `task-workflow` line 98 auto-stages new files with `git add`. Remove.
5. `task-workflow` lines 61–89 duplicate stack rules from `CLAUDE.md`. Replace with "read repository `CLAUDE.md`, `AGENTS.md`, and applicable `.claude/rules`".
6. `task-workflow` line 158 mandates `Positive Observations` in review output. Remove mandate.
7. `task-workflow` has no `mode` parameter. Add `plan|execute|autonomous`.
8. `mvp-safety-review:61` publish-gate says `Control plane (.agents/, templates/, replit.md) not in git` — conflicts with Variant B (`.agents/skills` is now runtime, copied into materialized project). Reconcile in Phase 4.

## Open lifecycle decision (resolved in Phase 0.5)

`.agents` lifecycle: **Variant B adopted** — materialized project is an active
dual-agent development project and includes `.agents/skills`, `AGENTS.md`,
`replit.md`. Engineering/customer handoff removes them via
`prepare-engineering-handoff.sh`. The `mvp-safety-review` publish-gate is
narrowed to distinguish runtime `.agents/skills` (allowed) from control-plane
`.agents/` content (still excluded). See
`docs/agents-lifecycle-decision.md`.
