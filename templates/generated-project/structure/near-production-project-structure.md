# Near-Production Project Structure

Structured for engineering handoff. Runs on Replit (`postgresql-16` injects
Postgres env vars, backend 5000 → external 80, Replit Secrets) AND local-dev
(`docker-compose --profile local`). Docker is local-dev only.

The tree below describes the active MVP project before handoff. Entries marked
removable or optional are legitimately absent after their documented removal
commands; do not recreate them merely to match this diagram.

## Root layout

```
<project-root>/
├── README.md
├── .env.example
├── .gitignore                            # excludes template control plane + Python files
├── .replit                               # Replit workspace config (run, ports, modules)
├── replit.nix                            # Replit Nix package deps
├── docker-compose.yml                    # local-dev only; orchestrates backend + frontend + postgres
├── .github/workflows/ci.yml
├── backend/                              # ALL Java/Maven artifacts live here
│   ├── pom.xml                           # parent POM, <packaging>pom</packaging>
│   ├── Dockerfile                        # backend image (local-dev only)
│   ├── lombok.config
│   ├── config/                           # Checkstyle config referenced by parent pom
│   │   ├── checkstyle.xml
│   │   └── checkstyle-suppressions.xml
│   ├── application/                      # REST + security + GlobalExceptionHandler
│   ├── service/                          # Business logic + MapStruct Entity↔Record + AppException family
│   ├── domain/                           # JPA entities + repositories ONLY (leaf)
│   ├── migrations/                       # Liquibase changelogs only
│   ├── observability/                    # reusable external-client metrics interceptor/timer
│   ├── event-logging-to-db-feature/       # removable MVP usage-logging Java surface; migration stays in migrations/
│   ├── cache-management/                  # optional complete L2 + multi-node invalidation stack
│   └── external-services/                # external clients — MANDATORY for any outbound HTTP/SDK/queue call; omit only if app has none
└── frontend/                             # React + TypeScript + Vite
    ├── package.json
    ├── vite.config.ts
    ├── tsconfig.json
    ├── Dockerfile                        # frontend image (local-dev only)
    ├── nginx.conf.template               # SPA routing + /api proxy for nginx runtime
    └── src/
```

**Hard rules** (artifact lives where it's served; root = project-level only):

- Parent `pom.xml` at `backend/pom.xml`, NOT at root.
- `lombok.config` at `backend/lombok.config`.
- Every child Maven module POM declares the parent-managed
  `org.projectlombok:lombok` dependency, including `migrations`, `observability`,
  removable feature modules, and optional `external-services`.
- `config/checkstyle*.xml` at `backend/config/`.
- `Dockerfile` split: `backend/Dockerfile` + `frontend/Dockerfile`. No root Dockerfile.
- `docker-compose.yml` at root (orchestrates backend + frontend + Postgres).

Build: `mvn -f backend/pom.xml ...` from root, or `cd backend && mvn ...`.

## REQUIRED scaffold files (anti-deletion list)

Past Replit sessions kept deleting these "non-essential-looking" files in
favor of inline alternatives, then we kept re-creating them by hand. They are
load-bearing — **never remove, replace, or inline them** without explicit
direction:

| File | Purpose | Why Replit keeps deleting it | Replacement is FORBIDDEN |
|---|---|---|---|
| `frontend/src/pages/Login.tsx` | Clerk `<SignIn/>` — the single sign-in surface the SPA routes to on `401`. | Replit assumes "auth provider owns its own page" and removes ours; without it the app dead-ends on 401. | Inlining the form inside `App.tsx` |
| `frontend/src/app/AppRoot.tsx` | Router + `AuthProvider` + `ProtectedRoute` — single auth/routing entry. | Replit mounts `<ClerkProvider>` in `main.tsx` and drops the token-getter bridge | Putting router/auth in `main.tsx` |
| `frontend/src/app/AppShell.tsx` | Top-header layout shell (Elevate — no sidebar). | Monolithic layout in `App.tsx` | Left sidebar navigation |
| `frontend/src/shared/ui/AppHeader.tsx` + `PageHeader.tsx` | Standard top nav + page title row. | Ad-hoc headers per page | One-off `<h1>` styling |
| `frontend/src/shared/hooks/useDebounce.ts` | Canonical debounce hook (structure-lint enforced). | Broken `useState`-only debounce hooks | Inline debounce in every feature |
| `frontend/src/shared/auth/AuthProvider.tsx` | Mounts `ClerkProvider` and bridges `useAuth().getToken()` into `runtime.ts` via `setSsoTokenGetter`. | Replit thinks `<ClerkProvider>` belongs in `main.tsx` — but then the token-getter bridge is missing and every authenticated fetch fires without a Bearer. | Putting `<ClerkProvider>` directly in `main.tsx` |
| `frontend/src/shared/auth/ProtectedRoute.tsx` | Clerk auth gate — redirects unsigned users to `/login`. | Inlining ad-hoc auth checks in every page | Custom per-page auth gates |
| `frontend/src/shared/ui/LoadingBlock.tsx` (+ `ErrorAlert`, `EmptyState`) | Standard async/query UI states (Elevate-styled). | Re-implementing loading/error/empty in every feature | Inline one-off status paragraphs |
| `backend/application/.../web/SpaFallbackController.java` | Serves `index.html` for client-side routes when Spring hosts the built SPA (Replit Deployment deep links). | Looks like unused MVC glue | Per-app route lists that miss new pages |
| `frontend/src/App.css` | Base layout / login form classes (`.login`, `.login__form`, etc.) referenced by `Login.tsx`. | Replit replaces with an ad-hoc `styles.css`, breaking the `bem-naming-rules.md` selector contract. | A `styles.css` parallel file |
| `frontend/src/App.test.tsx` | Vitest smoke: app renders, auth shell behaves. Part of the MVP safety suite. | Replit treats tests as optional and deletes them when refactoring. | Skipping the test suite |
| `scripts/setup-project.sh` | First-run cleanup: installs `.gitignore`, removes Replit Python injection, untracks template-only sources while preserving both active agent surfaces, and copies runtime scripts to `scripts/`. Does **not** replace `PACKAGE_REPLACE_ME` — run `scripts/apply-package-name.sh` for that. | Manual one-off sed/find commands |
| `scripts/apply-package-name.sh` | Mechanical `PACKAGE_REPLACE_ME` → `com.aidigital.<app>` rename + `groupId` update. Run once when scaffolding. | Ad-hoc package renames that miss directories |
| `scripts/strip-scaffold-samples.sh` | One-shot removal of the reference sample aggregate (sample/* packages + 0002-sample-reference.xml + its `<include>` in `db.changelog-master.xml`). Run as part of landing the first real aggregate. | Replit sees a "cleanup script" with no business logic and skips it — but without it the generated project ships with `Sample*` classes and an orphaned reference table. | Hand-deleting one file and forgetting the changelog-master edit (Liquibase boot crash) |
| `scripts/structure-lint.sh` | Architecture grep gate (sample survival, controller placement, module edges, AppRoot shell). Runs in `local-verify.sh` and `replit-build.sh`. | Agent ships layer violations that compile but fail handoff | Manual review only at publish time |
| `docker-compose.yml` | Local-dev orchestration (backend + frontend + Postgres). Required for handoff. | Replit doesn't need Docker, so it's "noise" inside the workspace. | Removing local-dev support |
| `.env.example` | Canonical env-var manifest. Lists every var consumed by `application.yml`, `vite.config.ts`, and the scripts. | Replit assumes Secrets pane is sufficient — but the manifest is the only source of truth for local-dev and handoff. | A README section listing vars |
| `README.md.template` | Project README skeleton (with placeholders for app name, owners, runbook links). | Replit overwrites with its own `replit.md`; the engineering README must survive. | A single `replit.md` for everything |

When Replit deletes any of these and a follow-up session needs them, regenerate
from the scaffold — do not invent a new variant.

## Scaffold sample aggregate (reference fixture — MUST be stripped)

The scaffold ships a `sample/` aggregate inside `domain/`, `service/`, and
`service/src/test/` whose ONLY purpose is to give the LLM a working,
compiling example of the canonical layer-by-layer layout (entity, repository,
mapper, record, service interface + impl with `@LogUsage`, service unit test).
A matching Liquibase changelog `db/changelog/changes/0002-sample-reference.xml`
creates the `samples` table so the project boots end-to-end.

**Contract:** these files are reference-only. They MUST NOT survive into the
generated project. The agent removes them in the same change as the FIRST
real aggregate's first commit — reading the patterns first, then deleting
the fixtures.

**Exact paths to delete** (whole directories — they are self-contained, zero
external references):

```
backend/domain/src/main/java/<base>/domain/sample/
backend/service/src/main/java/<base>/service/sample/
backend/service/src/main/java/<base>/service/mappers/sample/
backend/service/src/test/java/<base>/service/sample/
backend/service/src/test/java/<base>/service/mappers/sample/
backend/migrations/src/main/resources/db/changelog/changes/0002-sample-reference.xml
```

And remove the corresponding `<include file="db/changelog/changes/0002-sample-reference.xml"/>`
line from `backend/migrations/src/main/resources/db/changelog/db.changelog-master.xml`.

The agent runs `scaffold/scripts/strip-scaffold-samples.sh` to do this in
one step. The script is idempotent and safe to run before the first real
aggregate exists (it just deletes the sample, leaving the project still
compilable because the `usage_events` changelog `0001-usage-events.xml` and
its corresponding `UsageEventEntity`/`UsageEventRepository` are NOT sample
fixtures — they back real `@LogUsage` infrastructure, all living together
inside the dedicated `event-logging-to-db-feature` Maven module).

**Forbidden:**
- Shipping a generated project with any `sample/` package surviving under
  `domain/`, `service/`, or their test counterparts.
- Leaving the `0002-sample-reference.xml` include in `db.changelog-master.xml`
  while the file itself is deleted (Liquibase fails at boot).
- "Renaming" the sample aggregate into the first real one in-place. The
  sample patterns are intentionally generic (`Sample`, `name`, `updatedAt`)
  — a real aggregate has its own domain vocabulary; rename hides the
  cleanup contract and lets dead `Sample` artifacts linger.

Every sample file carries a `SCAFFOLD EXAMPLE — REFERENCE ONLY` banner at
the top so the agent cannot mistake it for production code mid-edit.

## Java package root

All generated Java code MUST live under:

```text
com.aidigital.<app-name-package>.*
```

`<app-name-package>` is the application name normalized for Java packages:
lowercase, alphanumeric only, no spaces, hyphens, underscores, or dots from the
display name. Examples:

- `Employee Directory` → `com.aidigital.employeedirectory`
- `Pull List` → `com.aidigital.pulllist`

Set `backend/pom.xml` `<groupId>` to the same value. Generated OpenAPI
packages derive from `${project.groupId}`:

```xml
<groupId>com.aidigital.employeedirectory</groupId>
<openapi.api.package>${project.groupId}.api.v1</openapi.api.package>
```

Forbidden package roots: `org.example`, `com.example`, `io.replit`, `demo`,
the raw app name with hyphens, or any package outside `com.aidigital.*`.

## Backend modules

Maven parent + 5 required modules, plus the removable
`event-logging-to-db-feature` MVP module and optional complete
`cache-management` stack. NO `common` Maven module and NO empty Maven modules
— cross-cutting service-layer types (AppException, ErrorReason) live under
`service/common/`. Usage-logging types live in `event-logging-to-db-feature`.

- `application` — Spring Boot entrypoint, REST controllers, generated API
  impls, security, GlobalExceptionHandler, Logbook/correlation/logging, Actuator,
  and Prometheus. Attaches `observability` for reusable outbound timing.
- `service` — business orchestration, validation, tx boundaries. HOSTS
  AppException family under `<base>/service/common/`. Depends on
  `event-logging-to-db-feature` so `*ServiceImpl` methods can carry `@LogUsage`.
- `domain` — JPA entities + repositories ONLY. Leaf.
- `migrations` — Liquibase changelogs + seed data.
- `observability` — reusable outbound-client observability:
  `ExternalClientMetricsInterceptor`, `ExternalCallTimer`, and the common
  low-cardinality timer schema.
  No product behavior and no internal-module dependencies.
- `event-logging-to-db-feature` — self-contained usage logging feature: `@LogUsage`
  annotation, `UsageEvent` record, `UsageLogger` interface +
  Postgres/NoOp impls, the AOP aspect, configs, `UsageEventEntity` +
  repository. Its `0001-usage-events.xml` migration remains centralized in
  `migrations`. The handoff command removes both together — see "Disabling
  usage logging" below.
- `cache-management` — optional as one complete stack with application L2
  wiring, the service/domain invalidation outbox, and its centralized
  migration. Keep all of it only for a concrete cache candidate; otherwise run
  `scripts/remove-cache-management.sh --apply`.
- `external-services` — external API adapters. **MANDATORY the moment the
  application makes ANY outbound network call.** Concrete triggers — if you
  catch yourself writing any of these from `application/` or `service/`,
  STOP and create `external-services/` first:

  - HTTP / REST clients: `RestClient.create()`, `WebClient.builder()`,
    `HttpClient.newBuilder()`, `RestTemplate`, `OkHttpClient`,
    `@FeignClient`, raw `URL.openConnection()`.
  - Vendor SDKs: Google APIs (Sheets, Drive, BigQuery, Pub/Sub, GCS),
    AWS (S3, SQS, SNS, Lambda), Stripe, Twilio, SendGrid, Slack, Notion,
    any `new <Vendor>Client(...)`.
  - Message-queue producers/consumers: Kafka, RabbitMQ, NATS, Pulsar.
  - Webhook senders, outbound gRPC stubs, search clients (Elastic / OpenSearch).

  TRUE LEAF (no internal deps). Throws `<Provider>ExternalException`;
  `service/` catches and wraps into `AppException(ErrorReason.X, ...)`.

  **BigQuery query construction:** the Google BigQuery SDK client lives in
  `external-services`, but BigQuery SQL construction belongs in `service`
  because it maps business search fields, filters, visibility, sorting, and
  paging to whitelisted SQL fragments. Follow
  `templates/generated-project/integrations/bigquery-query-rules.md`: one typed
  builder emits both the paged data query and the matching count query over the
  same `WHERE` clause; user input never supplies table names, columns, raw
  predicates, field lists, or order expressions.

  **Past failure mode:** an LLM reads "OPTIONAL" and decides the project
  doesn't "really" need a separate module, drops the Google Sheets fetch
  into the controller directly. The controller then carries HTTP-client
  imports, retry logic, and CSV-parsing — three concerns the structure
  expressly forbids in `application/`. Result: the rule needs an *active*
  rewrite (move client → external-services, parse → service) instead of
  reaching the right shape on the first write.

  **Acceptable absence:** the application makes zero outbound network calls
  (pure CRUD over the project's own Postgres, no third-party data fetch,
  no email/SMS/webhook). In that case do not create the module, do not list
  it in parent `<modules>`, do not add it to `<dependencyManagement>`.
  A POM-only module with no real client source is rejected — empty modules
  train future edits to preserve dead structure.

  When adding the module retroactively (the app gained its first integration
  later), the module skeleton AND the first client/adapter source files land
  in the **same change**.

  Grep-check: `RestClient\|WebClient\|HttpClient\|RestTemplate\|OkHttpClient\|FeignClient`
  must produce zero matches under `backend/application/src/main/java/` and
  `backend/service/src/main/java/`.

## Backend module dependency graph (REQUIRED edges)

Dropping an edge is the #1 cause of "build passes but runtime breaks".

```
application ──► service ──► domain
            └─► migrations                        (runtime-only — see below)
            └─► observability                     (reusable external-client metrics)
            └─► domain                            (only while cache wiring imports ToWarmUp)
            └─► cache-management                  (runtime-only, when cache stack is installed)

service     ──► domain
            ──► event-logging-to-db-feature       (brings @LogUsage onto *ServiceImpl)
            ──► cache-management                  (when cache stack is installed)
            └─► external-services                 (when external-services exists)

event-logging-to-db-feature
            ──► (JPA + AOP + spring-security)     (LEAF internally — no internal deps)
cache-management                                  (LEAF internally)
observability
            ──► (micrometer-core + spring-context + spring-web) (LEAF internally)
domain                                            (LEAF)
external-services ──► observability               (outbound metric interception/timing;
                                                    present iff app has outbound calls)
migrations  ──► liquibase-core                    (LEAF internally)
```

### Disabling usage logging

Two paths, in increasing aggressiveness:

1. **Runtime toggle (no rebuild):** set `app.usage-logging.enabled=false`
   (env `USAGE_LOGGING_ENABLED=false`). The aspect's
   `@ConditionalOnProperty` drops out; `NoOpUsageLogger` binds; the
   `usage_events` table stays. `@LogUsage` annotations remain inert markers.
2. **Full removal:** drop `<module>event-logging-to-db-feature</module>` from
   `backend/pom.xml`, drop the `event-logging-to-db-feature` dependency line from
   `backend/service/pom.xml`, delete `@LogUsage` usages from `*ServiceImpl`,
   and remove the `<include file="db/changelog/changes/0001-usage-events.xml"/>`
   line from `backend/migrations/src/main/resources/db/changelog/db.changelog-master.xml`.
   (`application` picks up `event-logging-to-db-feature` transitively through `service`, so
   no explicit application/pom edit is required.) Also set
   `USAGE_LOGGING_ENABLED=false` in `.env.example` so CI's usage-logging gate
   stays consistent. This prevents fresh schemas from creating the table; it
   does not drop or erase `usage_events` from an existing database. Engineering
   must make an explicit retention/archive/drop decision for existing data.

**Critical edge: `application → migrations`.** Migrations run at RUNTIME via Spring
Boot's Liquibase auto-config; changelog XMLs only land in the fat jar if
`application` depends on `migrations`. Drop this edge → green build + runtime crash
`Liquibase: changelog 'db/changelog/master.xml' not found`.

**Conditional edge: `service → external-services`.** Present whenever
`external-services` exists (which is whenever the app makes any outbound
call — see Backend modules above). Added in the same change as the first
real client/adapter source files. A POM-only `external-services` module is
worse than no module because it trains future edits to preserve dead
structure.

**Conditional cache edges.** While the complete cache stack is installed,
`application → domain` is required by `ToWarmUp`, and both `application` and
`service` attach `cache-management`. Running
`bash scripts/remove-cache-management.sh --apply` removes those edges and the
entire L2/invalidation stack together.

**Forbidden edges:**
- `application → domain` unless the complete cache stack is installed.
- `application → external-services` directly (route through `service`).
- `service → application` — cycle.
- `domain → service` / `domain → application` — leaf.
- `external-services → service` / `external-services → domain` — leaf.
- `migrations → anything internal` — XML only.

Versions pinned in `backend/pom.xml` `<dependencyManagement>`; children
reference by `<artifactId>` only.

### Forbidden module-boundary anti-patterns (file-placement crimes)

Each row is a real past failure — files compile in isolation but break the
build because they sit in the wrong module:

| Anti-pattern | Why it breaks | Correct placement |
|---|---|---|
| `*ApiMapper.java` (or anything importing the generated `api.v1.*` package) in `service/` | `service` does NOT depend on `application` and therefore cannot see generated OpenAPI types. Build fails with `package <base>.api.v1 does not exist`. Agent then "fixes" by adding `application` as a dependency of `service` — reverse edge, cycle, build never recovers. | `application/mappers/<aggregate>/<X>ApiMapper.java` — converts ServiceRecord ↔ generated DTO |
| `*Mapper.java` (Entity ↔ Record) in `application/` | `application` doesn't import JPA entities (it sees only ServiceRecord through `service`). Mapper has nothing to map. | `service/mappers/<aggregate>/<X>Mapper.java` |
| `@RestController` in `service/` | `service` doesn't depend on `spring-web`. Compile error on `@RestController`. | `application/<aggregate>/controllers/<X>Controller.java` |
| Controller directly under `application/<aggregate>/` (e.g. `application/sheets/SheetsProxyController.java`) instead of `application/<aggregate>/controllers/<X>Controller.java` | Breaks the "plural = collections" folder contract; future second controller for the same aggregate has nowhere consistent to land. Past sessions then "fix" by adding it next to the first — spreading inconsistency. | `application/<aggregate>/controllers/<X>Controller.java` (plural folder, always) |
| `@RestController` class with `@RequestMapping("/api/v1/...")` and method-level `@GetMapping`/`@PostMapping` instead of `implements <Tag>Api` | Bypasses the generated OpenAPI interface contract — spec and runtime drift silently; frontend `openapi-fetch` and backend serve different paths until the first mismatch ships to prod. | `class <X>Controller implements <Tag>Api` with `@Override` on every method; only annotation on class is `@RestController`. See `openapi/canonical-openapi-rules.md` → "Backend contract boundary". |
| `@Entity` in `service/` or `application/` | JPA annotations require `spring-data-jpa`, only in `domain`. Even if it compiles, Hibernate scans only `domain` packages. | `domain/<aggregate>/entities/<X>Entity.java` |
| `AppException` / `ErrorReason` in `application/` or per-aggregate folders | They are cross-cutting service contracts; controllers throw via service. Splitting them creates duplicate `ErrorReason` enums and ambiguous catches in `GlobalExceptionHandler`. | `service/<base>/service/common/error/` — SINGLE source |
| `LogUsage` / `UsageEvent` / `UsageLogger` outside `event-logging-to-db-feature/` (e.g. service/common/observability or application/observability) | Past sessions scattered usage-logging code across 4 modules; killing the feature meant editing each one. The annotation, aspect, sink interface, entity and repo all live together in the `event-logging-to-db-feature` Maven module — that's the contract. | `event-logging-to-db-feature/src/main/java/<base>/usagelogging/…` (entity + repository in sub-packages). Note: the Liquibase changelog `0001-usage-events.xml` does NOT live here — all migrations sit in `backend/migrations/src/main/resources/db/changelog/changes/`, per the single-source rule. |
| `AppUser` / `CurrentUser` / any authenticated-principal value object in `application/security/` | Service-impl methods need the principal (audit, authorisation). If it lives in `application/`, service can't import it without a reverse-edge cycle. Past sessions tried to "fix" by extending the record (Java records are final) or re-exporting — both dead ends. | `service/<base>/service/common/security/AppUser.java` — declared in service, used by both application's `SecurityConfig` and service-impl methods. The minimal `spring-security-core` dep can be added to `service/pom.xml` if needed for `Authentication`/`GrantedAuthority` types. |
| `<Provider>Client` in `service/` | External HTTP-client deps live in `external-services` only. Service catches the provider's exception and wraps. | `external-services/<provider>/<Provider>Client.java` |
| Java source files in `migrations/src/main/java/` | `migrations` is changelog-only. Adding Java code there means you've reinvented something that should live in `domain`/`service`. | Delete; rebuild the concern in the correct module |
| Two `@ConfigurationProperties` classes with the same prefix, or duplicate `@ConditionalOnProperty` on the same bean | Spring fails at startup with "more than one bean of type X". Symptom of agent copy-pasting a config from one aggregate to another. | Single `@Configuration` per concern; conditional logic lives on one bean, not on duplicates |
| Two `@ExceptionHandler` methods in `GlobalExceptionHandler` for overlapping exception types (e.g. one for `Exception`, one for `RuntimeException`) | Spring resolves "ambiguous handler method" at startup or at first error — depends on classpath order. | One handler per leaf exception type; have the catch-all (`Exception.class`) sit alone as the last line of defence |

**Grep-able review check:**
```bash
# zero matches across all five checks; otherwise the build is structurally broken
grep -rn "api.v1\." backend/service/src/main/java/
grep -rn "@Entity\|@Table" backend/service/src/main/java/ backend/application/src/main/java/
grep -rn "@RestController\|@RequestMapping" backend/service/src/main/java/

# Routing annotations on controller classes/methods (must use generated interface)
grep -rn "@RequestMapping\|@GetMapping\|@PostMapping\|@PutMapping\|@PatchMapping\|@DeleteMapping" \
  backend/application/src/main/java/*/*/controllers/

# Controllers placed outside the controllers/ folder (loose under <aggregate>/)
find backend/application/src/main/java -type f -name '*Controller.java' \
  ! -path '*/controllers/*'
```

## Backend package layout (strict — inside each module)

Plural = collections, singular = namespaces. Agent defaults to singular →
silently fragments. Always plural.

```
application/src/main/java/<base>/
  Application.java                                  # @SpringBootApplication
  config/LogbookConfig.java                         # metadata-only masked Logbook bean
  security/                                         # SecurityConfig, JwtDecoders, AuthProperties
  error/                                            # GlobalExceptionHandler (@RestControllerAdvice)
  observability/CorrelationIdFilter.java            # inbound correlation ID/MDC
  <aggregate>/                                      # ONE folder per domain aggregate
    controllers/<X>Controller.java
  mappers/                                          # ALL API mappers live here
    <aggregate>/<X>ApiMapper.java                   # ServiceRecord ↔ V1 DTO, ONE per entity

observability/src/main/java/<base>/
  observability/external/ExternalClientMetricsInterceptor.java
  observability/external/ExternalCallTimer.java

service/src/main/java/<base>/service/
  common/                                           # cross-cutting, NOT per-aggregate
    error/
      AppException.java
      ErrorReason.java                              # THE single enum, replaces AppErrorReason interface
      ValidationMessage.java
      ValidationParameter.java
      ValidationMessageType.java
  <aggregate>/                                      # ONE folder per domain aggregate
    services/<X>Service.java                        # interface
    services/impl/<X>ServiceImpl.java               # @Service impl; every public method auto-logged (UsageLoggingAspect)
    models/
      <X>Record.java                                # output record (immutable)
      <X>Update.java                                # write input
      <X>Query.java                                 # filter input (when needed)
  mappers/                                          # ALL service mappers live here
    <aggregate>/<X>Mapper.java                      # Entity ↔ Record, ONE per entity, compose via uses=

domain/src/main/java/<base>/domain/
  <aggregate>/                                      # ONE folder per domain aggregate
    entities/<X>Entity.java                         # @Entity, JPA-mapped
    repositories/<X>Repository.java                 # extends JpaRepository

event-logging-to-db-feature/src/main/java/<base>/usagelogging/      # usage-logging Java surface (NO migrations — those live in migrations/)
  LogUsage.java                                     # annotation (import from here)
  UsageAttributes.java                              # ThreadLocal helper; caller fills the JSONB `attributes`
  UsageLoggingAspect.java                           # @Aspect, intercepts @LogUsage (kept at root with LogUsage/UsageAttributes — uses their package-private contract)
  models/UsageEvent.java                            # value record
  loggers/UsageLogger.java                          # sink interface
  loggers/impl/PostgresUsageLogger.java             # @Postgres sink impl
  loggers/impl/NoOpUsageLogger.java                 # used when app.usage-logging.enabled=false
  config/UsageLoggingConfig.java                    # @Configuration: binds sink + executor
  config/UsageLoggingProperties.java                # app.usage-logging.* binding
  persistence/UsageEventPersistenceService.java     # @Async + REQUIRES_NEW INSERT bean
  entities/UsageEventEntity.java                    # JPA mapping for usage_events (BQ-aligned schema)
  repositories/UsageEventRepository.java            # JpaRepository

external-services/src/main/java/<base>/external/        # present iff app makes outbound calls; never POM-only
  <provider>/                                       # ONE folder per external API
    <Provider>Client.java                           # interface
    <Provider>ClientImpl.java                       # Feign/RestClient impl
    <Provider>ExternalException.java                # thrown OUT — service module wraps it

migrations/src/main/resources/db/changelog/                 # Liquibase XML only, NO Java — ALL migrations live here, including feature-module tables (e.g. 0001-usage-events.xml backs the usage_events table)
```

**Migration single-source rule:** every Liquibase changelog in the project
lives under `backend/migrations/src/main/resources/db/changelog/changes/` and is
referenced from `db.changelog-master.xml`. Feature modules
(`event-logging-to-db-feature`, future ones) own their `@Entity` /
`@Repository` Java code, but never their own `src/main/resources/db/`. One
place for migrations means one classpath, one tool to grep, one location to
review when answering "what's the current schema?".

**Migration precondition rule:** every Liquibase `changeSet` must declare
direct `preConditions`. For create-table changes, use `onFail="MARK_RAN"` plus
`not/tableExists`; for create-index changes, use the matching index existence
check. `scripts/verify-gates.sh` runs `scripts/lib/check-liquibase-preconditions.sh`.

## Testing layout (MVP safety suite)

Canonical policy: `templates/generated-project/testing/testing-policy.md`.
The generated project is not complete with zero tests. MVP requires a lean
safety suite; handoff adds strict coverage and deeper integration tests.

Backend tests live beside the Maven module that owns the behavior:

```
application/src/test/java/<base>/
  smoke/
    ApplicationSmokeTest.java                       # context + health endpoint
  <aggregate>/controllers/
    <X>ControllerTest.java                          # auth boundary + API contract
  error/
    GlobalExceptionHandlerTest.java                 # ApiErrorV1 mapping, when needed

service/src/test/java/<base>/service/
  <aggregate>/services/
    <X>ServiceImplTest.java                         # happy path + main AppException path

application/src/test/java/<base>/migrations/
  LiquibaseChangelogSmokeTest.java                  # master changelog applies, when DB exists
```

Frontend tests use Vitest and live with the UI/hook they verify:

```
frontend/src/
  app/
    App.test.tsx                                    # render/auth shell smoke
  features/<feature>/
    <feature-name>.test.tsx                         # critical user flow
  shared/
    api/client.test.ts                              # auth-aware client behavior, when customized
```

MVP minimum:
- backend: app/health smoke, auth boundary, main happy path, main error path,
  service unit tests, Liquibase smoke when persistence exists.
- frontend: main render smoke, auth/session behavior, loading/error/success
  states for primary server-backed surfaces, critical form/action behavior.

Handoff minimum:
- backend: Testcontainers integration tests, OpenAPI contract tests, edge
  cases, business invariants, and `bash scripts/local-verify.sh` while
  `.template-phase` is `engineering` at 80% line coverage.
- frontend: expanded behavior coverage for critical flows and role-dependent
  states; avoid snapshot-only suites.

Folder-naming hard rules:

| Plural (collections) | Singular (namespaces) |
|---|---|
| `services/`, `services/impl/` | `common/` |
| `mappers/` | `error/` |
| `models/` | `observability/` |
| `entities/` | `security/` |
| `repositories/` | `config/` |
| `controllers/` | `usage/` |

Never write singular `service/`, `mapper/`, `entity/`, `repository/`, `model/`,
`controller/` — forbidden.

## Module-level rules

- Controllers implement generated OpenAPI interfaces; thin (≤6 lines, no conditionals).
- Only `*ServiceImpl` carries `@Service`; every public impl method is auto-logged
  by `UsageLoggingAspect` (`@LogUsage` optional, to override the action name).
- Entities/repositories never appear in REST contracts.
- DB via Liquibase. MapStruct for all conversion. One entity = one mapper per layer; compose via shared mapper config + `uses=`.
- Create/update field copying must stay in MapStruct (`toEntity(...)` /
  `updateEntity(..., @MappingTarget ...)`); services must not build entities
  with `new *Entity()` plus setter chains.
- Service-layer inputs are records under `service/<aggregate>/models/`
  (`Create<X>Model`, `Update<X>Model`, etc.); do not create `*Command` types.
- Current time comes from `service/common/time/CurrentTime`; no direct
  `LocalDateTime.now(...)` / `Instant.now()` in production business code.
- Service interfaces return typed records. Do not expose `Map<String,Object>` or raw `Object` for business request/result contracts; isolate dynamic provider/JSONB maps in boundary converters.

### Global API mapper anti-pattern (FORBIDDEN)

Never create a single mapper such as `ApiDtoMapper`, `DtoMapper`,
`ApplicationMapper`, `CommonMapper`, or a `application/.../mappers/<aggregate>/*` package root
class to translate every generated DTO. API mapping follows the aggregate
boundary: one entity/resource = one API mapper under `mappers/<aggregate>/`.

Correct examples:

```text
backend/application/src/main/java/<base>/mappers/lesson/LessonApiMapper.java
backend/application/src/main/java/<base>/mappers/lessonactivity/LessonActivityApiMapper.java
backend/application/src/main/java/<base>/mappers/roadmap/RoadmapApiMapper.java
```

When one DTO contains nested DTOs owned by another aggregate, compose mappers
with MapStruct `uses = OtherApiMapper.class`. Do not inline nested conversion
and do not move unrelated mappings into a generic mapper to avoid wiring
`uses`.

Forbidden examples:

```text
backend/application/src/main/java/<base>/mappers/ApiDtoMapper.java
backend/application/src/main/java/<base>/mappers/DtoMapper.java
backend/application/src/main/java/<base>/mappers/ApplicationMapper.java
```

Forbidden code shape:

```java
@Component
public class ApiDtoMapper {
    LessonV1 toLesson(LessonRecord record) { ... }
    MaterialV1 toMaterial(MaterialRecord record) { ... }
    RoadmapV1 toRoadmap(RoadmapRecord record) { ... }
}
```

Correct code shape:

```java
@Mapper(config = ApplicationMapperConfig.class, uses = LessonActivityApiMapper.class)
public interface LessonApiMapper {
    LessonV1 toDto(LessonRecord record);
}
```

`structure-lint.sh` rejects wrong mapper packages, root/global API mappers,
application mappers that are not MapStruct `@Mapper` interfaces, and manual
`default Map<String,Object> -> DTO` mapping hidden inside mapper interfaces.
`verify-gates.sh` also runs scanners that reject entity setter-chain mapping
and direct current-time calls in app-owned backend modules.

Artificial list wrappers are forbidden. Do not create records such as
`LessonsListSource`, `UsersListSource`, or `SomethingResponseSource` under
`application/.../mappers/**`, and do not replace them with one-field service
records such as `LessonsListRecord(List<LessonSummaryRecord> lessons)`. Simple
list use cases return `List<T>` directly; API mappers map that list parameter
into generated wrapper response DTOs.

Manual `default` mapping methods inside MapStruct mappers are forbidden except
for tiny scalar adapters annotated by MapStruct qualifiers. API mappers must not
construct generated DTOs with `new ...V1()` and must not import `ApiMappingSupport`;
that is manual mapping and belongs in typed service records plus MapStruct
abstract methods.
- Business errors as `AppException(ErrorReason.X, ...)` — never per-domain enums.
- Usage logging: `templates/generated-project/observability/usage-logging-rules.md`.
- Multi-node cache invalidation: `.claude/agent_docs/distributed_cache.md`.
  The scaffold supplies the active DB outbox, monotonic-ID poller, migration,
  and shared Hibernate/Spring JCache bridge. The generated app populates the
  registry and adds transactional publication calls for its actual cached data.

## JPQL / PostgreSQL query rules (known footguns)

Apply to every repository method with a nullable filter parameter.

**Rule 1 — Never call `LOWER(:param)` on a nullable JPQL parameter.**
Postgres infers SQL `NULL` as `bytea` → runtime crash `function lower(bytea)
does not exist`. Hibernate's metamodel doesn't catch this.

```jpql
// FORBIDDEN — crashes when :namePattern is null
@Query("select e from EmployeeEntity e where :namePattern is null or LOWER(e.fullName) like LOWER(:namePattern)")

// CORRECT — pre-lowercase in the service
@Query("select e from EmployeeEntity e where :namePattern is null or LOWER(e.fullName) like :namePattern")
```

```java
String namePattern = query.fullNameLike() == null ? null
    : "%" + query.fullNameLike().toLowerCase(Locale.ROOT) + "%";
```

**Rule 2 — Case-insensitive search:** `LOWER(column) LIKE :param`. Never
`ILIKE` (not portable JPQL). Add a functional index on `lower(column)` via Liquibase.

**Rule 3 — Every nullable filter needs `:p is null or …`.** JPQL `=` against null is `unknown`.

**Rule 4 — Never cast a nullable parameter inline** (`CAST(:p AS text)` hits
the same `bytea` problem). Cast in service if needed.

Review: `grep -rn 'LOWER(:' domain/src/main/java/` → zero matches.

## Frontend layout

Feature-first React (Bulletproof React shape, see
`templates/generated-project/frontend/canonical-react-frontend-rules.md`):

```
frontend/src/app          # AppRoot (router + auth), AppShell layout
frontend/src/pages        # route-level composition only (incl. Login.tsx)
frontend/src/features     # feature modules (UI + hooks + feature API); copy _template/
frontend/src/entities     # reusable domain UI/models
frontend/src/shared/api   # generated OpenAPI types + auth-aware fetcher
frontend/src/shared/auth  # AuthProvider — Clerk wrapper + token-getter bridge
frontend/src/shared/ui    # reusable design-system components
frontend/src/shared/lib   # framework-agnostic helpers
frontend/src/shared/config
```

## Runtime: Replit vs local-dev

| | Replit | Local-dev |
|---|---|---|
| PostgreSQL | `PGHOST`/`PGPORT`/`PGDATABASE`/`PGUSER`/`PGPASSWORD` → HikariDataSource; no forced SSL | docker-compose Postgres |
| Backend port | `5000` → external `80` | `8080` |
| Frontend dev | Vite `5173` (preview only) | Vite `5173` |
| Frontend in Deployment | Spring serves `frontend/dist/` from `src/main/resources/static/` | n/a |
| Secrets | Replit Secrets pane | `.env` (gitignored) |
| Profile | `replit` (Hikari `2–3`) | `local` (Hikari `50`) |
| Auth | Clerk SSO only (Bearer JWT validated vs Clerk JWKS) | Clerk SSO (set issuer/JWKS + Clerk keys) |

Both share `application.yml` as base. See
`.claude/skills/backend-java-feature/references/database-url-translation.md`.

Auth is Clerk SSO only (Bearer JWT validated against the Clerk JWKS); see
`templates/generated-project/auth/google-sso-clerk-blueprint.md`.

`server.forward-headers-strategy=framework` is set in `application.yml` so
Spring honours `X-Forwarded-*` behind Replit's edge (absolute URLs / Swagger /
CORS resolve to the public `https://*.replit.dev` host, not
`http://localhost:5000`).

### Startup budget on Replit Reserved VM

Reserved VM closes its port-check window roughly **30 seconds** after the
process starts. Spring Boot binds Tomcat in the LAST step of `refresh()`,
AFTER every bean initialises — so Liquibase + Hibernate's JDBC dialect
probe + JPA entity scan all gate the bind. Past incident: cold-start hit
~40s+, the platform killed the JVM mid-`refresh()`, and the deploy looped
silently (no exception, just fresh PIDs).

`application-replit.yml` (THIS PROFILE ONLY — not the base, not local-dev)
ships with the following knobs to keep cold-start under ~10s:

| Setting | What it skips | Trade-off |
|---|---|---|
| `spring.main.lazy-initialization=true` | Eager bean construction → Tomcat binds before JPA/MapStruct/security/Logbook init | First request to each cold path is ~200ms-1s slower |
| `spring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect` | Hibernate's JDBC dialect probe (multi-second on cold pool) | Pins the dialect — Replit is always Postgres, fine |
| `hibernate.boot.allow_jdbc_metadata_access=false` + `temp.use_jdbc_metadata_defaults=false` | The catalog/schema metadata round-trip at boot | **Requires** the explicit dialect above, else Hibernate throws "Unable to determine Dialect without JDBC metadata" |

If cold-start still blows the budget after these knobs (typically when
Liquibase grows past ~10s of migrations), the next escalation is
`spring.liquibase.enabled=false` + running Liquibase from an
`ApplicationListener<ApplicationReadyEvent>` AFTER the port binds. That
lets the platform mark the deploy healthy while migrations stream in the
background — at the cost of requests landing on a half-migrated schema
for a short window. Reach for it only when the four knobs above aren't
enough.

Do NOT copy these knobs into `application.yml` (base) or
`application-local.yml`. Local-dev keeps eager init so misconfigurations
fail loudly on `mvn spring-boot:run`; lazy-calinit would mask them.

## Local-dev dry-run (handoff only)

```bash
docker compose --profile local config
docker compose --profile local up --build -d
curl -f http://localhost:8080/<app-context-path>/actuator/health
curl -f http://localhost:8080/<app-context-path>/actuator/prometheus
docker compose --profile local down -v
```
