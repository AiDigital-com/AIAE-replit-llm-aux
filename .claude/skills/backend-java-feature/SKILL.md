---
name: backend-java-feature
description: Build the backend for ANY generated project in this template. The template's backend is ALWAYS Java 21 LTS + Spring Boot 3.x + Maven + PostgreSQL — never Python/Flask/Django, never Node/Express, never anything else. Use for every backend feature regardless of how simple the user prompt sounds.
metadata:
  user-invocable: "true"
---

# Backend Java Feature

Use for **every** backend change. Stack lock: `CLAUDE.md`.

Before applying usage-logging guidance, inspect
`backend/event-logging-to-db-feature/`. Its presence means the project is still
in the MVP feedback phase. Its absence means engineering handoff removed the
temporary telemetry surface: do not recreate the module, `@LogUsage`, or
`UsageAttributes` unless the project explicitly adopts a production analytics
design.

## Baseline (non-negotiable)

Java 21 · Spring Boot 3.x · Maven multi-module · OpenAPI contract-first ·
Liquibase · PostgreSQL · package root `com.aidigital.<app-name-package>.*`.

Run `bash scripts/apply-package-name.sh <app-name-package>` once after copying
the scaffold. Replace every `PACKAGE_REPLACE_ME` — never use `com.example`.

HTML-only inputs still get the Java backend when usage logging, persistence,
auth, analytics, or multi-user review is required. Migrate UI code into
`frontend/`, keep the backend in `backend/`, and follow
`templates/generated-project/generation/html-only-project-migration.md`.

## Canonical references (do not duplicate)

| Topic | File |
|---|---|
| Structure | `templates/generated-project/structure/near-production-project-structure.md` |
| Entity-service boundary | `templates/generated-project/structure/entity-service-boundary-policy.md` |
| Architecture rules (full) | `references/backend-workflow-details.md` |
| Testing | `templates/generated-project/testing/testing-policy.md` |
| Backend test style | `templates/generated-project/testing/backend-test-style-rules.md` |
| OpenAPI | `templates/generated-project/openapi/canonical-openapi-rules.md` |
| Auth (Clerk SSO only) | `templates/generated-project/auth/google-sso-clerk-blueprint.md` |
| Usage logging | `templates/generated-project/observability/usage-logging-rules.md` |
| Operational observability / HTTP logging | `templates/generated-project/observability/logbook-http-logging-rules.md` |
| Performance engineering | `templates/generated-project/performance/performance-engineering-rules.md` |
| L2 and cross-node cache invalidation | `.claude/agent_docs/distributed_cache.md` |
| BigQuery query construction | `templates/generated-project/integrations/bigquery-query-rules.md` |
| Code patterns | `references/code-patterns.md` |
| Spring gotchas | `references/spring-boot-gotchas.md` |
| Hikari/JPA YAML | `references/hikari-jpa-baseline.yml` |
| Replit datasource | `references/database-url-translation.md` |
| Scaffold | `backend/`, `frontend/`, and `scripts/` |

## Workflow

1. **Copy, don't regenerate** — scaffold POMs, YAML, `SecurityConfig`, `SpaFallbackController`.
2. **OpenAPI first** — update `openapi.yaml`, run review checklist, regenerate interfaces.
3. **Thin controllers** — implement generated `*Api`; ≤6 lines; no repositories
   and no transaction ownership. Transactions belong on the narrow service
   database phase and never span external HTTP/SDK/storage/AI calls.
4. **Service interface + impl** — business logic in `*ServiceImpl`; inject interface, not impl.
5. **MapStruct only** — entity↔record in `service/`, record↔DTO in `application/`; no `new *Entity()` / `new *V1()` setter chains.
6. **CurrentTime only** — inject `CurrentTime` for timestamps; no direct `LocalDateTime.now(...)` / `Instant.now()` in business code.
7. **Liquibase** — every `changeSet` has direct `preConditions`; verify gates reject missing preconditions.
8. **Errors** — single `ErrorReason` enum + `AppException` only.
9. **Auth** — Clerk JWT via `SecurityConfig`; resolve caller with `AppUserFactory`; no mock/Replit OIDC.
10. **Cache mutations** — if the project contains cache annotations or
    `backend/cache-management/`, keep the complete L2/query-cache and
    cross-node invalidation stack together. When a mutable source feeds that
    cache,
    register its regions and publish the invalidation outbox event inside the
    same service transaction; follow `.claude/agent_docs/distributed_cache.md`.
    When the project has no cache, do not add the stack speculatively.
11. **Tests** — Phase 2 minimums per `testing-policy.md` before publish.
12. **Module/client invariants** — every Maven submodule declares Lombok;
    reusable outbound metrics (`ExternalClientMetricsInterceptor` and
    `ExternalCallTimer`) live in `backend/observability`; every third-party
    Spring HTTP client comes from `PooledRestClientFactory` with both metrics
    and `LogbookClientHttpRequestInterceptor` interception.

Full architecture, module matrix, port lock, build flags, gotcha table:
`references/backend-workflow-details.md`.

## Local verify

```bash
bash scripts/local-verify.sh
```

Skip docker-compose dry run on Replit when Docker is unavailable; document why in README.
