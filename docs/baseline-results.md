# Baseline results

Recorded during the dual-runtime repair on 2026-07-27. This is a reproducible
baseline, not a claim that external deployment or real-world skill validation
has occurred.

## Source provenance

The pre-split source repository
`../ai-digital-replit-llm-aux` was observed with a dirty, staged/modified
`.claude/skills/performance-review/SKILL.md`. It was not edited during this
work. The canonical performance skill remains marked **needs real-world
validation** in `AIAE-llm-aux/docs/validation-status.md`.

## Script discovery and syntax

All `*.sh` files in `scripts/` and
`templates/generated-project/scaffold/scripts/` were discovered regardless of
executable bit and checked with `bash -n`.

| Category | Commands | Result |
|---|---|---|
| Common validation | `bash scripts/validate-skills.sh`, `bash tests/test-render-skills.sh` in AIAE-llm-aux | pass |
| Common sync | `bash scripts/sync-llm-aux.sh`, `--check`, `bash scripts/test-sync-drift.sh` | pass after generation |
| Payload/materialization | `check-payload-portability.sh`, `test-materialize-project.sh` | pass |
| Release | `test-release-replit-template.sh` | pass |
| Scaffold deterministic tests | setup, strip-samples, Clerk, scanner, materialization tests | pass in the reviewed baseline |
| Full local verification | `ci-verify-scaffold.sh` with Java 21 | pass; one Testcontainers/Liquibase smoke skipped when Docker daemon was unavailable |
| Docker smoke | `docker-local-smoke.sh`, `docker-context-path-smoke.sh` | skipped: Docker CLI present, daemon unavailable |

## Environment note

The host defaulted to Java 17; six integration checks failed until Java 21 was
selected. The scaffold requires Java 21. CI and local setup should preflight or
select Java 21 before Maven execution.

## Artifact inventory contract

Active materialized/release projects must include `AGENTS.md`, `replit.md`,
`.agents/skills`, `CLAUDE.md`, `.claude/skills`, `.claude/rules`,
`.claude/agent_docs`, and `.claude/tasks/README.md`. Engineering handoff then
removes only `AGENTS.md`, `replit.md`, `.agents`, `custom_instruction`, and
`templates`, preserving the Claude surface.
