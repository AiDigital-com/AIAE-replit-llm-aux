# CLAUDE.md

This file provides reusable engineering guidance to Claude Code. Apply it to
the current repository after discovering that repository's actual structure,
package root, build commands, ports, and existing product decisions.

## Project Overview

The default supported architecture is a Spring Boot backend and a React
frontend. Preserve an existing project's established stack and layout unless
the user explicitly requests a migration.

Common top-level areas:

- `backend/` — Java 21, Spring Boot 3.4, multi-module Maven backend
- `frontend/` — React + TypeScript + Vite frontend
- `.claude/` — self-contained Claude rules, docs, skills, and task artifacts for this repository

## Start Here

1. Read `.claude/agent_docs/index.md`.
2. For backend work, read the relevant docs before changing code:
   - `project_structure.md`
   - `building_the_project.md`
   - `running_tests.md`
   - `code_conventions.md`
   - `database_schema.md`
   - `service_architecture.md`
   - `performance_engineering.md` for request flows, transactions, queries,
     external calls, logging, caching, pools, or payload work
3. For frontend work, read the relevant docs before changing code:
   - `project_structure.md`
   - `building_the_project.md`
   - `running_tests.md`
   - `frontend_architecture.md`
   - `frontend_style.md`
   - `frontend_testing.md`
   - `performance_engineering.md` for data fetching, request counts, payloads,
     rendering, or bundle work
4. Respect `.claude/rules/*.md`.
5. Read `.claude/agent_docs/skill-selection.md` before choosing between GSD,
   `task-workflow`, and a focused skill.
6. Read `.claude/agent_docs/context7.md` before using external library or
   framework documentation. Use the configured Context7 MCP for
   version-sensitive APIs; fall back to official vendor docs when unavailable.
7. Before applying a path, package, port, module, navigation, or test command
   from these docs, verify it against the current repository.

## Enterprise Hard Constraints

- Keep the rule set self-contained when it is installed into a project; do not
  depend on another local checkout or a machine-specific absolute path.
- Read `.claude/agent_docs/project_shape_decision.md` before deciding
  frontend-only vs full-stack work.
- Do not hand-edit generated backend OpenAPI sources or generated frontend OpenAPI types.
- Do not add dependencies casually. Use the existing stack and local patterns first.
- Keep secrets out of frontend code and public environment variables.
- Never request an MCP/API key in chat or commit one. Authentication belongs in
  the user's OAuth session, shell environment, or secret manager.
- Never replace an established product flow, navigation model, or visual system
  with a template default unless the user explicitly asks for that change.

## Backend Hard Constraints

- Backend stack is fixed: Java 21, Spring Boot 3.x, Maven multi-module, PostgreSQL, Liquibase.
- Every Liquibase `changeSet` must declare direct `preConditions`; the generated verify gate rejects changelogs without them.
- Discover and preserve the repository's single production package root; do not
  introduce a second root or placeholder packages.
- Backend controllers implement generated OpenAPI interfaces and stay thin.
- Backend JPA repositories are accessed only through their paired entity service.
- Reusable outbound metrics live in `backend/observability`; it owns
  `ExternalClientMetricsInterceptor` and `ExternalCallTimer`. Application-owned
  Logbook configuration, correlation filtering, logging, Actuator, and
  Prometheus remain in `backend/application`.
- Backend tests follow the project style from `.claude/rules/20-tests.md`.

## HTML-Only Source Projects

If the input project is standalone HTML/CSS/JS but the user needs usage
logging, analytics, action review, persistence, auth, or multi-user visibility,
do not keep it static-only. Migrate the UI into `frontend/`, add the fixed Java
backend under `backend/`, and serve the built Vite app from Spring Boot for
Replit deployment. During the MVP feedback phase, when
`backend/event-logging-to-db-feature/` is present, persist usage events to its
PostgreSQL `usage_events` table. After engineering handoff the module is
intentionally absent; do not recreate it unless the project explicitly chooses
a production analytics design. Read
`.claude/agent_docs/html_only_project_migration.md` before implementing.

## Frontend Hard Constraints

- Frontend stack is fixed: React, TypeScript, Vite, TanStack Query, Clerk, `openapi-fetch`, plain CSS with BEM.
- Frontend API calls go through the generated OpenAPI client boundary under `frontend/src/shared/api`.
- Preserve the product's established navigation model. For a new project with
  no explicit design, follow the installed frontend design guidance.
- Frontend styles follow BEM and semantic CSS tokens; do not introduce Tailwind, CSS Modules, styled-components, Emotion, or CSS-in-JS.
- Frontend tests follow the project style from `.claude/rules/50-frontend-tests.md`.
