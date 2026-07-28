# Replit Custom Template — AI Digital MVP

## Overview

Custom Template configuration repository (not a runnable app). On fork, the
Replit Agent uses these rules/skills/artifacts to generate near-production
MVPs for non-technical users.

Generated MVPs run on Replit (SQL Database, port 5000), export to local-dev
via `docker-compose --profile local`, and hand off to engineering with full
quality gates.

Authoritative rules: `custom_instruction/instructions.md`. Replit workflows:
`.agents/skills/*/SKILL.md`; Claude Code workflows are separately installed at
`.claude/skills/*/SKILL.md`. Canonical artifacts: `templates/generated-project/*`.

## Vibe-coder happy path

1. **Clerk Auth first** — before Run: enable Replit-managed Clerk Auth so
   `CLERK_PUBLISHABLE_KEY` and `CLERK_SECRET_KEY` are injected. Set
   `AUTH_AUTHORIZED_PARTIES` to your app origins (required). Issuer/JWKS derive
   from the publishable key when `AUTH_ISSUER_URI` / `AUTH_JWKS_URI` are blank.
   See `.env.example` for the full list.
2. **Fork bootstrap** — `setup-project.sh` on boot (Python purge + install `scripts/`).
3. **Package** — `bash scripts/apply-package-name.sh <app-name-package>`.
4. **Scaffold** — copy from `templates/generated-project/scaffold/` (`SCAFFOLD-MANIFEST.md`);
   never Spring Initializr / `npm create vite`.
5. **First feature** — `generation/first-aggregate-checklist.md` (OpenAPI → codegen → layers).
6. **UI** — copy `src/features/_template/`; router stays in `src/app/AppRoot.tsx`.
7. **Publish** — `bash scripts/local-verify.sh` from **project root**.

Tell the Agent: Clerk SSO only, typed `shared/api/client.ts`, strip samples with
`strip-scaffold-samples.sh` when the first real aggregate lands.

## User Preferences

- Stack lock absolute (Java 21 + Spring Boot 3.x + Maven; React + TS + Vite).
  Override phrase + forbidden list: `custom_instruction/instructions.md` →
  "ABSOLUTE STACK LOCK".
- Audience: non-technical product users; explanations stay business-focused.
- Auth: Clerk SSO only (required — no mock/replit fallback); mocked/approved-only
  data; real keys in Replit Secrets.
- Code: simple over clever; canonical artifacts over hand-written boilerplate.
- Performance: follow
  `templates/generated-project/performance/performance-engineering-rules.md`;
  baseline request/query/payload behavior before tuning and prevent
  cross-layer load amplification.
- UI: Elevate design system, compact product surfaces, no left side menu.
- Generation budget: reference canonical files, never paste — see
  `templates/generated-project/generation/token-efficient-generation-rules.md`.
- When in doubt: smallest demo that publishes on Replit; document what
  engineering must replace.

## System Architecture

### Template repo layout

```
custom_instruction/instructions.md         # authoritative rules
replit.md                                  # this file
.replit                                    # Replit workspace config
replit.nix                                 # Nix packages
.agents/skills/<name>/SKILL.md             # Replit-discovered workflows
.claude/skills/<name>/SKILL.md             # Claude Code workflows
.claude/rules/*.md                         # authoritative project rules
.claude/agent_docs/*.md                    # background documentation
agent-payload.skills                       # which skills ship into projects
templates/generated-project/*              # canonical artifacts + scaffold/
.github/workflows/ci.yml                   # template integrity CI
```

### Generated project default stack

- **Backend**: Java 21 LTS + Spring Boot 3.x + Maven multi-module + PostgreSQL +
  Liquibase + HikariCP + Lombok + Checkstyle + JaCoCo. OpenAPI contract-first.
  Lombok is declared in every Maven submodule, including `migrations` and optional
  modules.
  Required modules are `application`, `service`, `domain`, `migrations`, plus the
  reusable `observability` module (`ExternalClientMetricsInterceptor` and
  `ExternalCallTimer`), plus the self-contained
  `event-logging-to-db-feature` usage-logging module (drop it to
  remove the feature at engineering handoff). The complete
  `cache-management` + L2 stack is optional as one unit; remove it with
  `scripts/remove-cache-management.sh` when the application has no cache
  candidate. `external-services` is optional only for real outbound
  integrations, never as an empty/POM-only module.
- **Frontend**: React + TypeScript + Vite + TanStack Query, typed via
  `openapi-typescript` + `openapi-fetch` from the backend OpenAPI YAML.
- **Auth**: Clerk SSO only (required). Backend validates Clerk JWTs against the
  Clerk JWKS via `spring-boot-starter-oauth2-resource-server`; fails fast when
  Clerk keys or `AUTH_AUTHORIZED_PARTIES` are unset. No mock/replit fallback.
- **Observability**: structured JSON logs to stdout, Actuator
  (`health`, `prometheus`), metadata-only/body-free production Logbook output,
  mandatory `LogbookClientHttpRequestInterceptor` on third-party Spring HTTP
  clients, and reusable outbound timing through `backend/observability`.
  Logbook/correlation/logging/Actuator configuration stays application-owned;
  Postgres `usage_events` remains separate product analytics.
- **Runtime split**: Replit → profile `replit`, port `5000`, Replit Postgres
  env vars (`PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`);
  Local-dev → profile `local`, port `8080`, `docker-compose --profile local`.
- **Scale assumption**: code is multi-node safe even if the current Replit
  deployment starts as one Reserved VM. No node-local correctness state/locks;
  scheduled work is idempotent/coordinated and caches invalidate across nodes.
  Redis is not installed and is only a future measured option.

Authoritative-references table: `custom_instruction/instructions.md` →
"Authoritative references".

### Replit deployment model

- **Reserved VM** (`deploymentTarget = "gce"`) — not Autoscale (cold starts
  break warm JVM + JDBC pool).
- **One public port**: 5000 → externalPort 80. Spring Boot serves `/api/*` AND
  the built React SPA from `src/main/resources/static/`. Vite (5173) is
  workspace-preview only.
- `onBoot` runs `templates/generated-project/scaffold/scripts/setup-project.sh`.
- Workspace `[env]` does NOT propagate to Deployments. Before publish, copy
  `SPRING_PROFILES_ACTIVE`, `CLERK_*`, `AUTH_*`, `USAGE_LOG_*`, and Replit
  Postgres env vars into Deployment Secrets when Replit does not auto-propagate.

## External Dependencies

Clerk SSO is REQUIRED — set keys in Secrets before first Run. Postgres + usage
logging are Replit-provided when enabled.

| Service | Purpose | Activation |
|---|---|---|
| **Clerk** | Google SSO. | `CLERK_PUBLISHABLE_KEY` + `CLERK_SECRET_KEY` in Replit Secrets. |
| **Google OAuth** (via Clerk) | Backing IdP. | Configured in Clerk Dashboard. |
| **Usage logging** | Telemetry → app's `usage_events` Postgres table. | `USAGE_LOGGING_ENABLED=true` + `USAGE_LOG_SERVICE_NAME`. |
| **PostgreSQL** | Persistence. | Replit `postgresql-16` injects Postgres env vars. Local-dev: docker-compose. |
| **Context7 MCP** | Current version-specific library/framework documentation for Replit Agent. | Connect once through [Replit Integrations](https://replit.com/integrations?mcp=eyJkaXNwbGF5TmFtZSI6IkNvbnRleHQ3IiwiYmFzZVVybCI6Imh0dHBzOi8vbWNwLmNvbnRleHQ3LmNvbS9tY3Avb2F1dGgiLCJoZWFkZXJzIjpbXX0%3D) using OAuth; never store its credential in the project. |

### Required env placeholders (`.env.example`)

Auth (Clerk SSO, required): `AUTH_ISSUER_URI`, `AUTH_JWKS_URI`, `AUTH_AUDIENCE`,
`CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY`, `CLERK_SIGN_IN_FORCE_REDIRECT_URL`,
`CLERK_SIGN_UP_FORCE_REDIRECT_URL`.

Usage logging: `USAGE_LOGGING_ENABLED`, `USAGE_LOG_SERVICE_NAME`,
`USAGE_LOG_ENVIRONMENT`.

### Prohibited

- Production secrets or data in MVPs.
- Frontend reaching DB or service-account keys.
- Committing service-account JSON.
- Hardcoded auth secrets.
