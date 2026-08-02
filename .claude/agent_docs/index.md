# Claude Engineering Context Index

This directory contains reusable Claude reference docs. When installed into a
project, keep the rule set self-contained: do not rely on external repositories
or machine-specific paths to understand it. Discover repository-specific facts
from the current checkout before applying examples.

## Repository-local Claude layout

- `CLAUDE.md` is the repository entrypoint and should stay short.
- `.claude/agent_docs/` contains detailed repository context and engineering conventions.
- `.claude/rules/` contains concise always-on or path-scoped rules that Claude should load automatically. See `.claude/agent_docs/rule-loading-conventions.md` for the naming/loading convention (always-on hard rules vs path-scoped topic rules).
- `.claude/skills/` contains reusable workflows and review gates: `task-workflow` (multi-role execution), `backend-rule-review`, `frontend-style-review`, `aiae-rule-compliance-audit` (whole-repo audit against the installed AIAE contract), `ui-designer` (visual-polish pass within the Elevate design system), and `local-preview` (fixtures plus a verified running demo).
- `.claude/tasks/` stores plan, summary, review, and test artifacts for individual tasks.

## What to Read

- Read `agent-operating-model.md` before delegating work, selecting model roles,
  asking the user for input, starting a local preview, or running final review.
- When `docs/architecture-overview.md` exists at the repository root, read it
  before cross-cutting product work. In a materialized project it is the
  canonical record of the implemented system context, runtime flows, module
  boundaries, data ownership, caching, integrations, deployment, and
  operational constraints. Update it when those facts change; do not copy its
  product-specific content into this reusable rule tree.
- Read `project_structure.md` when locating modules, packages, generated code, frontend features, shared frontend utilities, or deciding where new classes/components belong.
- Read `project_shape_decision.md` before deciding frontend-only vs full-stack work.
- Read `building_the_project.md` before compiling, packaging, running Vite, or choosing Maven/npm commands.
- Read `running_tests.md` before adding or changing backend or frontend tests.
- Read `code_conventions.md` before changing backend production code.
- Read `database_schema.md` before touching backend JPA entities, repositories, JPQL/HQL, cache settings, or Liquibase.
- Read `html_only_project_migration.md` before converting a standalone HTML/CSS/JS project that needs logging, auth, persistence, analytics, or multi-user review.
- Read `service_architecture.md` before changing backend entity services, RBAC services, orchestrators, validators, or external-service boundaries.
- Read `performance_engineering.md` before changing request flows, transaction
  boundaries, queries, pagination, integrations, caching, pools, file transfer,
  frontend fetching, or bundle/loading behavior.
- Read `distributed_cache.md` before adding Hibernate L2/query caching,
  Spring caching, cache warm-up, or mutations of cached data.
- Read `context7.md` before using external library/framework documentation or
  configuring the project-level Context7 MCP.
- Read `frontend_architecture.md` before changing React components, frontend API access, auth flow, routing, feature layout, or Vite configuration.
- Read `frontend_style.md` before changing CSS, visual layout, component classes, or UI structure.
- Read `frontend_testing.md` before adding or changing frontend unit/component/API tests.
- Read `skill-selection.md` before choosing GSD, `task-workflow`, or a focused review/design/verification skill.

## Embedded Enterprise Rules

The rule groups are fully described in this repository-local `.claude` tree. Do not replace them with references to external paths. If a rule changes, update the local doc or rule file directly.

Key enterprise rule groups:

- Backend stack: Java 21, Spring Boot 3.x, Maven multi-module, PostgreSQL. Discover and preserve the current repository's production package root.
- OpenAPI contract boundary: YAML is the contract, backend controllers implement generated interfaces, generated sources are not edited, frontend generated API types are not edited.
- Persistence baseline: PostgreSQL, Liquibase, `Long` ids, `TEXT` columns, JPA/Ehcache/Hikari configured at application level.
- Backend service boundaries: `1 entity = 1 repository = 1 service`, no repository access from controllers or cross-entity orchestration services.
- Backend configuration: use `@ConfigurationProperties`, not `@Value`.
- External integrations: outbound clients live under `backend/external-services`, use configurable HTTP clients, and keep credentials in configuration.
- Frontend stack: React + TypeScript + Vite, TanStack Query for server state, Clerk for auth, OpenAPI-generated types with `openapi-fetch`, and plain CSS with BEM.
- Frontend API boundary: no raw `fetch`, `axios`, `XMLHttpRequest`, or hardcoded backend URLs in `frontend/src`; all protected calls send Bearer JWT through the shared client.
- Frontend UI structure: preserve the project's established navigation model. Within operational pages prefer compact page headers, tabs, filter bars, segmented controls, and contextual toolbars.
- Frontend styling: BEM class names, semantic CSS custom properties, flat class selectors, no CSS Modules, Tailwind, styled-components, Emotion, or CSS-in-JS.
- Testing style: backend and frontend tests use `should ...` naming, `// Given:` / `// When:` / `// Then:` sections, local test setup, explicit assertions, and meaningful behavior coverage.
- Logging and observability: structured JSON logging expectations and centralized web/error handling.
- Performance: measured request/query/payload baselines, bounded APIs,
  transaction-safe external I/O, set-based persistence, cancellable frontend
  requests, metadata-only production HTTP logging, and evidence-driven
  cache/pool/index decisions.

## Maintenance Rules

- Keep this `.claude` tree self-contained when distributing it to a project.
- Add new reusable engineering rules here instead of pointing to another local repository.
- Keep project facts such as names, package roots, ports, vendors, and one-off
  layout decisions in project-local documentation, not in this shared rule set.
- Keep `CLAUDE.md` short and route to these docs instead of duplicating them.
- Promote concise always-on or path-specific constraints into `.claude/rules/`.
