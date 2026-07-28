# Claude Code Setup

How to work with an AIAE generated project using Claude Code locally.

## Project-level (automatic)

When a project is materialized (Variant B), it contains:

```text
CLAUDE.md
.claude/skills/
.claude/rules/
.claude/agent_docs/
.claude/tasks/
```

Claude Code automatically discovers project-level skills in `.claude/skills/`
and auto-loads rules from `.claude/rules/`. No additional setup is needed —
clone the project and start Claude Code.

## Common skills

The following common skills are generated into `.claude/skills/` from
`AIAE-llm-aux` (pinned in `llm-aux.lock`):

- `verification-gate`
- `production-code-review`
- `fullstack-performance-audit`
- `task-workflow`

Each generated skill file has a provenance header identifying its source and
revision. Do not edit generated skills directly — update them in
`AIAE-llm-aux` and re-sync.

## Project-specific skills

These skills are project-specific and maintained directly in the project:

- `backend-rule-review` — Java/Spring compliance review against installed rules.
- `frontend-style-review` — React frontend review.
- `aiae-rule-compliance-audit` — concrete AIAE compliance audit.

## Updating common skills

```bash
bash scripts/sync-llm-aux.sh --update-lock   # repin revision= to the source HEAD
bash scripts/sync-llm-aux.sh                 # regenerate both registries
git diff -- .claude/skills .agents/skills     # review
git add llm-aux.lock .claude/.llm-aux-manifest .agents/.llm-aux-manifest .claude/skills .agents/skills
```

Commit the lock change and the regenerated files together, or
`scripts/test-sync-drift.sh` fails in CI. `sync-llm-aux.sh --check` verifies
without writing anything.

## User-level installation (optional)

If you work across many AIAE projects, you may install common skills at the
user level so they are available even in projects that have not synced them:

```bash
cd /path/to/AIAE-llm-aux
revision=$(git rev-parse HEAD)
output="$HOME/.local/share/aiae-llm-aux/claude-skills"
bash scripts/render-skills.sh \
  --target claude \
  --output "$output" \
  --revision "$revision"

mkdir -p "$HOME/.claude/skills"
for skill in "$output"/*/; do
  name=$(basename "$skill")
  ln -sfn "$skill" "$HOME/.claude/skills/$name"
done
```

This is optional and machine-specific. Project-level generated skills take
precedence. Do not link the raw `skills/` source tree: templated skills must be
rendered so no `{{TASK_STATE_DIR}}` token survives installation.

## Global `~/.claude/CLAUDE.md`

A global user-level `CLAUDE.md` is useful for company-wide process rules that
apply to every project:

- company development process;
- MCP host routing rules;
- credential handling policy;
- Git safety policy;
- team ownership links.

Do NOT put project-specific rules (Java, React, Clerk, BEM, Replit deployment)
in the global file — those belong in the project-level `CLAUDE.md`.

See `docs/permissions-hardening.md` for the recommended `~/.claude/settings.json`.
