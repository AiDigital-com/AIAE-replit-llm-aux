# Scaffold manifest — copy verbatim, never regenerate

Generators strip Replit-specific fixes. **Rule:** `cp` from `templates/generated-project/scaffold/`,
replace only `PACKAGE_REPLACE_ME` and app placeholders.

`PACKAGE_REPLACE_ME` → `com.aidigital.<app-name-package>` via
`bash scripts/apply-package-name.sh <app-name-package>`.

## Replit / root orchestration

| File | Notes |
|---|---|
| `.replit` | Materialized into generated project root by `materialize-project.sh` |
| `replit.nix` | Materialized into generated project root; JDK 21 + Node 22 + Postgres 16 |
| `docker-compose.yml` | `--profile local`, port 8080, Postgres health-check |
| `.env.example` | Full `AUTH_*`, `USAGE_LOG_*`, `CLERK_*`, `VITE_*` placeholders |
| `.gitignore` | Excludes template-only sources (`templates/`, `custom_instruction/`); keeps both active `.agents/` and `.claude/` surfaces |
| `AGENTS.md.template` | Tracked generated-project Replit entry point; materialized as root `AGENTS.md` |
| `replit.md.template` | Tracked active-project Replit context; materialized as root `replit.md` without control-plane paths |
| `.husky/pre-commit` | Root Git hook installed by `frontend` prepare script; runs `npm --prefix frontend run lint` |
| `CLAUDE.md`, `.claude/` | Materialized shared engineering rules and focused skills; GSD runtime remains opt-in |
| `AI-DEVELOPMENT-GUIDE.md` | Visible decision guide for focused skills vs optional GSD |

## Backend (copy from scaffold/backend/)

| File | Notes |
|---|---|
| `backend/pom.xml` | Java 21, Spring Boot 3.4, pluginManagement |
| `backend/application/pom.xml` | `migrations` + reusable `observability` deps, openapi-generator, PostgreSQL driver, optional Ehcache / Hibernate JCache |
| `backend/service/pom.xml` | No web/security deps |
| `backend/domain/pom.xml`, `backend/migrations/pom.xml` | Leaf modules; every module POM declares managed Lombok |
| `backend/observability/` | Reusable attachable outbound metrics: `ExternalClientMetricsInterceptor`, `ExternalCallTimer`, and the low-cardinality `external.client.requests` schema; no product/internal module dependencies |
| `backend/.../web/SpaFallbackController.java` + focused MVC test | Deployment deep links and exclusion of API routes |
| `backend/.../error/GlobalExceptionHandler.java` | Extends `ResponseEntityExceptionHandler`, delegates to `GlobalExceptionResponseHelper`, no private methods |
| `backend/.../error/mapper/GlobalExceptionResponseHelper.java` | Error response builder interface (generated API DTOs) |
| `backend/.../error/mapper/GlobalExceptionResponseHelperImpl.java` | Error response builder implementation; public helper methods stay in a component so the handler has no private helpers |
| `backend/.../service/common/error/AppException.java` | Single unchecked service exception, implements `CodeAwareThrowable` |
| `backend/.../service/common/error/CodeAwareThrowable.java` | Stable code contract exposed to the REST handler |
| `backend/.../service/common/error/ErrorReason.java` | Single enum of business error codes |
| `backend/.../service/common/error/ValidationMessage.java` | Parameterised error message value object |
| `backend/.../service/common/error/ValidationParameter.java` | Named error parameter |
| `backend/.../service/common/error/ValidationMessageType.java` | `{ ERROR, WARN, INFO }` |
| `backend/.../service/common/time/CurrentTime.java` | Injectable application time boundary; business code must use this instead of direct `*.now()` calls |
| `backend/.../service/common/time/CurrentTimeImpl.java` | UTC implementation of `CurrentTime` |
| `backend/cache-management/` | Active, removable multi-node invalidation mechanism: transactional DB outbox → monotonic-ID bounded poll → clear registered node-local regions. The scaffold supplies runtime wiring, JPA store, migration, scheduling, and an empty app-owned registry extension point. |
| `backend/.../cache/CacheConfig.java` | Shares one Ehcache/JCache manager between Hibernate L2 and Spring caching and wires optional warm-up |
| `backend/.../cache/CacheProperties.java` | `@ConfigurationProperties("app.cache")` for cache warm-up toggle |
| `backend/.../cache/CacheWarmUpService.java` | Startup warm-up runner for beans implementing `ToWarmUp` |
| `backend/.../domain/ToWarmUp.java` | Marker interface for cache warm-up participants |
| `backend/application/src/main/resources/ehcache.xml` | Ehcache 3 region template (`default` + `example`) |
| `backend/application/src/main/resources/api/v1/specs/openapi.yaml` | Starter contract with `AppApiExceptionResponseV1`, `AppValidationExceptionResponseV1`; pagination/search schemas are added per-entity when needed |

## Frontend (copy from scaffold/frontend/)

| File | Notes |
|---|---|
| `vite.config.ts` | `allowedHosts`, `@/` alias, port 5173, static outDir |
| `package.json` | `generate:api`, `check:api`, `test`, `lint`, Husky `prepare` |
| `eslint.config.js`, `eslint-rules/import-section-order.mjs` | ESLint rules for import sections, `.tsx` model extraction, and top-level static constants |
| `src/main.tsx` | Mounts `app/AppRoot` only — no ClerkProvider here |
| `src/app/AppRoot.tsx` | Router + AuthProvider + ProtectedRoute |
| `src/app/AppShell.tsx` | Top-header layout (no sidebar) |
| `src/pages/Login.tsx`, `login.css` | Responsive centered Clerk auth surface using semantic tokens |
| `src/shared/ui/AppHeader.tsx`, `PageHeader.tsx` | Elevate shell |
| `src/shared/hooks/useDebounce.ts` | Canonical debounce |
| `src/features/_template/` | Copyable feature module (panel + test) |
| `src/shared/api/client.ts` | Typed openapi-fetch boundary |

## Scripts (installed to project `scripts/` by setup-project.sh)

| Script | Role |
|---|---|
| `setup-project.sh` | onBoot: safe cleanup (no materialization without package name); prints next-step command |
| `replit-env.sh` | Shared Replit env normalization for dev workflow, build, and deployment |
| `apply-package-name.sh` | Package rename |
| `strip-scaffold-samples.sh` | Remove reference sample aggregate |
| `remove-cache-management.sh` | Remove L2 cache and cross-node invalidation together for projects with no cache |
| `remove-usage-logging.sh` | Remove MVP feedback telemetry at engineering handoff |
| `scripts/lib/liquibase_dependency_guard.py` | Blocks feature removal when active later changelogs still depend on its tables |
| `structure-lint.sh` | Architecture grep gate (`--scaffold` for template source) |
| `verify-gates.sh` | Shared runtime/publish grep gate (CI + local-verify) |
| `scripts/lib/check-openapi-strict-schemas.sh` | Rejects loose OpenAPI DTO schemas and generated unknown index signatures |
| `scripts/lib/check-openapi-documentation.sh` | Requires descriptions on OpenAPI operations, schemas, fields, parameters, and request bodies |
| `scripts/lib/check-liquibase-preconditions.sh` | Requires direct `preConditions` on every Liquibase `changeSet` |
| `scripts/lib/check-frontend-ui-rules.sh` | Rejects raw `px`/hex CSS drift, broken overflow/button reset, and forms without accessible validation hooks |
| `scripts/lib/check-production-current-time.sh` | Rejects direct production `*.now()` calls in app-owned backend modules; use `CurrentTime` |
| `scripts/lib/check-production-manual-mapping.sh` | Rejects `new *Entity()` plus setter-chain manual mapping; use MapStruct |
| `scripts/lib/check-service-contract-quality.sh` | Rejects undocumented service contracts and oversized ServiceImpl classes |
| `local-verify.sh` | Pre-push: lint + gates + mvn verify + frontend test/build |
| `ci-verify-scaffold.sh` | Template CI: materialize → strip samples → full verify |
| `replit-build.sh` / `replit-run.sh` | Deployment |

If you must regenerate (major upgrade): diff against this manifest — preserve every setting.
