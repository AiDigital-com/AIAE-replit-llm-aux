# Optional GSD Workflow

GSD is useful for multi-phase features, migrations, long-running investigations,
and work that must persist across Claude Code sessions. It is unnecessary for a
small, bounded change; use the focused project skills and `verification-gate`
instead.

The repository does not vendor GSD runtime files. This avoids committing hundreds
of generated upstream files, stale absolute paths, update churn, and Claude hooks
for developers who do not use GSD. Replit never initializes GSD automatically:
Replit Agent does not consume Claude Code's GSD runtime, and setup must not spend
agent credits on an unused workflow.

## Install locally

Run from the project root when you intend to use GSD with Claude Code:

```bash
npx -y @opengsd/gsd-core@latest --claude --local
```

Reload Claude Code, then verify:

```bash
test -f .claude/gsd-core/VERSION
test -f CLAUDE.md
test -f .claude/rules/00-backend-hard-rules.md
test -f .claude/skills/backend-rule-review/SKILL.md
```

The installer-generated runtime stays local through `.gitignore`. Commit only
the engineering contract: `CLAUDE.md`, `.claude/agent_docs/`, `.claude/rules/`,
`.claude/skills/`, and `.claude/tasks/README.md`.

## Normal GSD lifecycle

Run slash commands inside Claude Code, not in the terminal:

```text
/gsd-map-codebase
/gsd-new-milestone
/gsd-discuss-phase
/gsd-plan-phase
/gsd-execute-phase
/gsd-verify-work
/gsd-ship
```

Use `/gsd-help` for the installed command list and `/gsd-progress` to resume.

## Backend rules audit and automatic fixes

For a quick read-only check, GSD is unnecessary. Run this in Claude Code:

```text
/backend-rule-review

Review the entire backend against CLAUDE.md, .claude/rules/00-backend-hard-rules.md,
and all backend agent docs. Confirm every scanner hit by reading the code. Report
only high-confidence findings with file:line, impact, required fix, and missing
verification. Do not edit code.
```

For a full autonomous audit-to-fix loop, use GSD:

```text
/gsd-audit-fix

Audit the entire backend against CLAUDE.md, .claude/rules/00-backend-hard-rules.md,
.claude/rules/10-architecture.md, .claude/rules/12-database.md,
.claude/rules/20-tests.md, .claude/rules/30-web-openapi.md, and the backend agent
docs. Treat backend-rule-review findings as mandatory input. Verify every finding
against current code before editing. Fix confirmed gaps one by one without
reverting unrelated work. Run the strongest affected Maven tests, structure lint,
and verification gates. Continue until review passes or report a concrete blocker.
```

Then run independent completion checks:

```text
/gsd-code-review

Review the resulting backend diff against CLAUDE.md and the original audit.
Prioritize correctness, security, architecture violations, and missing behavioral
tests. Findings first, ordered by severity.
```

```text
/gsd-verify-work

Verify every fixed audit item with fresh command output. Do not accept build-only
evidence for behavioral claims. Report passed, failed, and unverified items.
```

For one narrow confirmed gap, prefer `/gsd-quick <concrete fix>` rather than
starting a milestone.

## Update or remove local GSD

```bash
npx -y @opengsd/gsd-core@latest --claude --local
npx -y @opengsd/gsd-core@latest --claude --local --uninstall
```

After either command, ensure the committed project rules and custom skills remain.
