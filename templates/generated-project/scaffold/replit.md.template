# Generated AIAE Project — Replit Runtime

This is an active dual-agent development project, not the reusable template
control plane. The application is already installed under `backend/` and
`frontend/`.

## Agent surfaces

- Replit Agent discovers workflows from `.agents/skills/`.
- `AGENTS.md` is the Replit entry point.
- `CLAUDE.md`, `.claude/rules/`, and `.claude/agent_docs/` contain the
  authoritative shared engineering contract.
- `.claude/skills/` is Claude Code's registry, not Replit's registry.

Use the focused skill that matches the request. Read only the linked topic
documents needed for the current work. Do not invent framework APIs or silently
relax repository rules when documentation or runtime evidence is unavailable.

## Fixed runtime

- Backend: Java 21, Spring Boot 3.x, Maven multi-module, PostgreSQL, Liquibase.
- Frontend: React, TypeScript, Vite, TanStack Query, Clerk, OpenAPI-generated
  types, plain CSS with BEM.
- Replit profile: `replit`, backend port `5000`, Reserved VM deployment.
- Local profile: `local`, backend port `8080`, Docker Compose.

React routing stays in `frontend/src/app/AppRoot.tsx` and uses `BrowserRouter`.
Spring and nginx deep-link fallbacks must remain enabled.

## First run

1. Enable Replit-managed Clerk Auth.
2. Confirm `CLERK_PUBLISHABLE_KEY` and `CLERK_SECRET_KEY` are available as
   Replit Secrets.
3. Set `AUTH_AUTHORIZED_PARTIES` to the application origins.
4. Run `bash scripts/configure-clerk-development.sh`.
5. Run `bash scripts/local-verify.sh`.
6. Use the Replit **Run** button.

Never paste or commit credentials. When publishing, copy required environment
values into Deployment Secrets if Replit does not propagate workspace secrets.

## Current framework documentation

Connect Context7 once through
[Replit Integrations](https://replit.com/integrations?mcp=eyJkaXNwbGF5TmFtZSI6IkNvbnRleHQ3IiwiYmFzZVVybCI6Imh0dHBzOi8vbWNwLmNvbnRleHQ3LmNvbS9tY3Avb2F1dGgiLCJoZWFkZXJzIjpbXX0%3D)
using OAuth. Context7 is preferred for version-sensitive APIs but never
overrides repository rules or pinned dependency versions.

## Verification and handoff

- Before claiming completion: `bash scripts/local-verify.sh`.
- Local Docker smoke: `bash scripts/docker-local-smoke.sh`.
- Before engineering handoff, use `finalize-coverage`, then
  `engineering-handoff`.
- Handoff removes `AGENTS.md`, `replit.md`, and `.agents/` while preserving
  `CLAUDE.md` and `.claude/`.
