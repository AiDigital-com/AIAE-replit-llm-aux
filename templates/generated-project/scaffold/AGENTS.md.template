# Generated Replit MVP

Authoritative engineering rules are in `CLAUDE.md` and `.claude/`. Replit Agent
also follows `replit.md` for environment-specific setup.

Read `AI-DEVELOPMENT-GUIDE.md` to choose between focused Claude skills and the
optional GSD lifecycle. GSD is never initialized automatically by Replit.
Read `.claude/agent_docs/project_shape_decision.md` before deciding frontend-only
vs full-stack work.
Read `docs/architecture-overview.md` before cross-cutting implementation,
integration, data, caching, deployment, or handoff decisions, and update it when
the implemented product architecture changes.

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

## Agent runtime surfaces

- **Replit Agent** uses `AGENTS.md`, `replit.md`, and `.agents/skills/`.
- **Claude Code** uses `CLAUDE.md`, `.claude/skills/`, `.claude/rules/`, and
  `.claude/agent_docs/`.
- `.agents/skills/` contains reusable workflows for Replit Agent.
- `.claude/rules/` and `.claude/agent_docs/` contain authoritative shared
  project rules and documentation.
- `.claude/skills/` is installed for local Claude Code and should not be
  treated as Replit's skill registry.

## Quick start

1. Add Clerk Auth in Replit (`CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY`).
2. Set `AUTH_AUTHORIZED_PARTIES` to your app origins.
3. Run `bash scripts/configure-clerk-development.sh`.
4. Run `bash scripts/local-verify.sh`.
5. Use the Replit **Run** button.

For version-sensitive library/framework documentation, use Context7 when the
Replit account has it connected. Add it once through the Context7 link in
`replit.md`; if unavailable, use official vendor documentation and do not guess
APIs.

## Engineering handoff

When transferring this project to engineering ownership, run
`bash scripts/prepare-engineering-handoff.sh` to remove Replit control-plane
files (`AGENTS.md`, `replit.md`, `.agents/`) while preserving `CLAUDE.md` and
`.claude/`.
