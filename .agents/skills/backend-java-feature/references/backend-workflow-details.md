# Backend Workflow Details

Extended architecture rules, module matrix, testing phases, and build flags.
Loaded on demand from `backend-java-feature/SKILL.md` — do not duplicate in skills.


Full layout: `templates/generated-project/structure/near-production-project-structure.md`
→ "Backend package layout" + "Backend module dependency graph" + "Forbidden
module-boundary anti-patterns".

Hard recap:
- Required Maven modules: `application`, `service`, `domain`, `migrations`,
  `observability`.
  `cache-management` is optional only as the complete L2 + multi-node
  invalidation stack; remove it with
  `bash scripts/remove-cache-management.sh --apply` when there is no cache.
  `external-services` is OPTIONAL and exists only when the project has real
  outbound integrations (HTTP APIs, queues, vendor SDKs, BigQuery clients,
  etc.). No empty Maven modules. No `common` Maven module — cross-cutting
  types live under `service/<base>/service/common/{error,observability,security,time}/`.
- If there are no external integrations, do NOT create `external-services`,
  do NOT list it in parent `<modules>`, do NOT add it to
  `<dependencyManagement>`, and do NOT depend on it from `service`.
- When an external integration is added later, add `external-services` in the
  same change as the first real client/adapter source files and wire
  `service -> external-services` then.
- BigQuery is split deliberately: the Google SDK client lives in
  `external-services`, while the whitelisted SQL request builder lives in
  `service` because it maps business search fields, filters, visibility,
  sorting, and paging. Follow
  `templates/generated-project/integrations/bigquery-query-rules.md`.
- Plural folders (`services/`, `mappers/`, `models/`, `entities/`,
  `repositories/`, `controllers/`) hold many artifacts of one kind. Singular
  (`common/`, `error/`, `observability/`, `security/`, `config/`, `usage/`)
  are namespaces. NEVER write singular variants of the plural ones — Agent
  defaults to singular and silently fragments the codebase.

### Dependency matrix (enforced by poms)

| From ↓ depends on → | application | service | domain | migrations | cache-management | external-services |
|---|---|---|---|---|---|---|
| `application` | — | ✓ | ✓ only with cache stack | ✓ | ✓ runtime, only with cache stack | ✗ |
| `service` | ✗ | — | ✓ | ✗ | ✓ only with cache stack | ✓ only when module exists |
| `domain` | ✗ | ✗ | — | ✗ | ✗ | ✗ |
| `migrations` | ✗ | ✗ | ✗ | — | ✗ | ✗ |
| `cache-management` optional | ✗ | ✗ | ✗ | ✗ | — | ✗ |
| `external-services` optional | ✗ | ✗ | ✗ | ✗ | ✗ | — |

- `application` calls only `service`; depends on `migrations` for runtime Liquibase
  changelogs (must land in the fat jar). With the cache stack installed, its
  warm-up wiring also imports `domain.ToWarmUp` and attaches
  `cache-management`; the removal script deletes both conditional edges.
- `service` calls `domain` repos and, only when needed, `external-services`
  clients.
- `domain`, optional `cache-management`, optional `external-services`, and
  `migrations` are leaves. External clients throw their own
  `<Provider>ExternalException`; service wraps via `AppException`.

### Forbidden dependencies per module (hard rule)

| Module | NEVER depend on | Why |
|---|---|---|
| `service` | `spring-boot-starter-security`, `spring-boot-starter-oauth2-resource-server`, `spring-boot-starter-web`, `spring-security-*`, `jakarta.servlet-api`, `io.jsonwebtoken:*` / `jjwt-*`, anything `org.springframework.web.*` | Service is business orchestration — no HTTP/JWT/caller knowledge. |
| `service` | `spring-boot-starter-data-jpa` (direct) | Uses repos from `domain` (transitive JPA is fine). Entities never escape service. |
| `domain` | `service`, `application`, `external-services`, anything except JPA + validation + Lombok | Pure leaf. |
| `external-services` (optional) | `domain`, `service`, `application`, `spring-boot-starter-data-jpa`, any `*Repository` | True leaf, NO internal deps. Exists only with real external clients. Throws own `<Provider>ExternalException`; service wraps. No DB. |
| `migrations` | Anything beyond `liquibase-core` | XML changelogs only. |

`domain` and optional `external-services` are LEAVES — internal `<dependency>`
in either pom → reject. Empty Maven modules are rejected; delete the module
until it contains real source/resources/tests owned by that module.

**Compile error `cannot find symbol: SecurityContextHolder` in `service/`:**
do NOT add spring-security to `service/pom.xml`. Remove `SecurityContextHolder`
from service code; add `AppUser caller` parameter; resolve the caller in the
controller from `SecurityContextHolder.getContext().getAuthentication()` and
`AppUserFactory.from(auth)`.

Examples: `references/code-patterns.md` → "AppUser pattern" + "Service that
needs DB + external call".

### Thin controllers (hard rule)

Controllers do ONLY four things:
1. Receive the generated API interface call.
2. Resolve authenticated user from `SecurityContext` (one line).
3. Call exactly ONE service method.
4. MapStruct → generated DTO; return.

Controllers implement generated OpenAPI interfaces exactly. Do not add
`@AuthenticationPrincipal`, `HttpServletRequest`, `NativeWebRequest`, or other
framework-only parameters to controller method signatures — the generated
interface will not have them. Need caller identity? Use `SecurityContextHolder`
inside the method. Need request metadata? Prefer a filter/aspect; if unavoidable,
inject/request-scope it outside the generated method signature. Never call
`getRequest()` on a generated API interface.

No `if`/`switch`, no DB calls, no business validation, no error wrapping,
no manual DTO construction.
Generated `*V1` DTO construction belongs to API mappers only. Controllers must
not call `new OkResponseV1()`, `new UploadUrlResponseV1()`, etc.; add a mapper
method and delegate to it.

**Hard limits (Agent has violated all):**
- Method body ≤ 6 lines (incl. braces).
- ZERO `if`/`else`/`switch`/`try`/`catch`/`for`/`while`/`?:` in any method.
  Exception: one-line ternary in `ResponseEntity` builder.
- ZERO `*Repository` injections (services + api-mappers only).
- ZERO direct `entityManager`/`JdbcTemplate`/`DataSource`.

Safety-review grep:
```bash
grep -rn 'private final.*Repository' application/src/main/java/**/controllers/  # expected: empty
```

**Controllers do not own transactions.** A controller transaction can retain a
database connection across API mapping, serialization, storage, AI, or
third-party calls. Put `@Transactional(readOnly = true)` on service read methods
and `@Transactional` on the narrow service write phase. The service maps the
entity to a fully initialized record before the transaction closes; entities
never escape the service boundary.

```java
@RestController
@RequiredArgsConstructor
class <Domain>Controller implements <Domain>Api {
    private final <Domain>Service service;
    private final <Domain>ApiMapper mapper;

    @Override
    public ResponseEntity<<Domain>V1> update<Domain>(Long id, Update<Domain>RequestV1 req) { ... }
}
```

An orchestration method that calls an external dependency is not transactional.
It calls a transactional entity/persistence service before and/or after the
external call, with explicit state and idempotency. Self-invoking a transactional
helper does not create a new proxy boundary; extract a collaborator.

Canonical + anti-pattern: `references/code-patterns.md` → "Thin controller".

### Service interface + impl (hard rule)

Interface in `services/`, impl in `services/impl/`. Inject the interface,
never the impl. Only `*Impl` carries `@Service`; `@Transactional` belongs on
impl methods. During the MVP feedback phase, an optional `@LogUsage` override
may also appear there. If `backend/event-logging-to-db-feature/` is absent,
usage logging was intentionally removed at engineering handoff and must not be
reintroduced implicitly. Layout: `references/code-patterns.md` → "Service
interface + impl".

Service method signatures are typed business contracts. Do not expose
`Map<String, Object>`, raw `Object`, or `List<Map<String, Object>>` as request
or result types for business flows. Dynamic provider JSON and JSONB maps must be
contained in named records or focused boundary converters.

### MapStruct between layers (hard rule)

Two mappers per resource: `Entity ↔ ServiceRecord` in `service/`,
`ServiceRecord ↔ ApiDto` in `application/`. Never handwrite
`new <Domain>V1(); dto.setX(...)` chains. Every mapper must use the shared
module mapper config with `unmappedTargetPolicy=ERROR`. Entities never
escape `domain`.

### One entity = one MapStruct mapper per layer (hard rule)

A single `ApiDtoMapper` is forbidden. Do not put all generated DTO mapping in
one flat/root mapper or an aggregate-owned mapper package. Each API mapper lives under `application/.../mappers/<aggregate>/`; cross-aggregate
nesting is composed through MapStruct `uses = OtherApiMapper.class`.
Manual default mapper methods accepting `Map<String, Object>` are forbidden; they mean the service contract is still untyped.
Artificial mapper source wrappers such as `LessonsListSource`, `UsersListSource`,
or `SomethingResponseSource` are forbidden. One-field service list wrappers such
as `LessonsListRecord(List<LessonSummaryRecord> lessons)` are also forbidden.
Simple list use cases return `List<T>` directly; API mappers map that parameter
into wrapper response DTOs with `@Mapping(target = "items", source = "items")`.


Exactly two mapper files per resource: `<Domain>Mapper` (service/) covers
all directions/list/page; `<Domain>ApiMapper` (`application/.../mappers/<aggregate>/`) covers all V1
schemas for this domain. Compose via `@Mapper(config = ..., uses = ...)`.

Named OpenAPI enum schemas are not resources, but they still need explicit
mapping ownership. Put reusable enum API mappers under
`application/.../mappers/common/` or the owning aggregate subfolder and reuse
them with MapStruct `uses = ...`. Never use generated inner enum types; inline
OpenAPI enums are forbidden.

Reject:
- **Mega-mapper** bundling multiple aggregates (Order + OrderItem + Customer).
- **Two mappers per entity per layer** (e.g. `EmployeeReadMapper` + `EmployeeWriteMapper`).
- **Inline nested conversion** when a dedicated mapper exists — use `uses = OrderItemMapper.class`.

Examples: `references/code-patterns.md` → "Two MapStruct mappers" + "MapStruct composition via `uses`".

## Error handling: one global `ErrorReason` enum (hard rule)

Full contract: `templates/generated-project/errors/error-handling-pattern.md`.

Exactly ONE enum at `<base>.service.common.error.ErrorReason`. Every
`AppException` is built from it:

```java
throw new AppException(ErrorReason.C001, id);                    // not found
throw new AppException(ErrorReason.C006, cause, "duplicate sku"); // conflict
```

**Forbidden** (Agent has done all):
- Per-domain enums (`EmployeeErrorReason`, `OrderErrorReason`).
- Recreating `AppErrorReason` interface — `AppException` takes the concrete enum.
- Splitting into `CommonErrorCodes` + `<Domain>ErrorCodes`.
- Throwing `ResponseStatusException`/`IllegalStateException`/`IllegalArgumentException`/
  `RuntimeException` — they bypass `GlobalExceptionHandler`'s code-prefix mapping.

Naming: enum constant IS the code, format `<L>nnn`. `C` is cross-cutting;
each domain claims a letter on first use (registry in `ErrorReason.java` docblock).
Non-400 status mappings → add branch in `statusForCode()`, never sprinkle status
logic in service/controller code.

## MapStruct mandatory — no manual mapping (hard rule)

```java
// FORBIDDEN
ResourceV1 dto = new ResourceV1();
dto.setId(record.id()); dto.setName(record.name());

CaseStudyEntity entity = new CaseStudyEntity();
entity.setTitle(model.title());
entity.setStatus("SUBMITTED");

// REQUIRED
return mapper.toDto(record);
CaseStudyEntity entity = mapper.toEntity(model);
mapper.updateEntity(model, entity);
```

Shared module mapper configs set `unmappedTargetPolicy=ERROR`. Unmapped
target → `@Mapping(target = "...", ignore = true)` or `constant = "..."`
(both keep compile-time check).

Create/update flows use aggregate-owned MapStruct methods:
`toEntity(Create<X>Model model)` for creation and
`updateEntity(Update<X>Model model, @MappingTarget entity)` for writable
updates. Service inputs are `*Model` records under
`service/<aggregate>/models/`; do not introduce service-layer `*Command` types.
Services may set technical fields such as timestamps or authenticated owner ids
after mapping, but all model/request field copying belongs in MapStruct.
`scripts/lib/check-production-manual-mapping.sh` rejects local
`new *Entity()` followed by setter chains in app-owned backend modules.

## CurrentTime mandatory — no direct now calls (hard rule)

Generated projects ship `service/common/time/CurrentTime` and
`CurrentTimeImpl`. Inject `CurrentTime` anywhere business/application code needs
the current time:

```java
private final CurrentTime currentTime;

entity.setCreatedAt(currentTime.nowLocalDateTime());
```

Do not call `LocalDateTime.now(...)`, `LocalDate.now(...)`,
`LocalTime.now(...)`, `Instant.now()`, `OffsetDateTime.now(...)`, or
`ZonedDateTime.now(...)` directly outside `CurrentTimeImpl` and tests.
`scripts/lib/check-production-current-time.sh` enforces this for app-owned
backend modules.

## Javadoc — input/output parameters MUST be documented (hard rule)

Every **public method** with at least one parameter, a non-void return, or a
thrown checked exception MUST carry Javadoc with `@param` for each parameter,
`@return` for the return value, and `@throws` for declared exceptions. This
applies to controllers, services, factories, mappers, configuration beans —
everything public. Generated code (OpenAPI, MapStruct) is exempt.

Past generations shipped controllers/services where the Javadoc was a single
summary line and `@param`/`@return` were absent, leaving the next reader
guessing what each parameter means (e.g. is `email` required? lowercased?
JWT-extracted or user-supplied?) and what edge-cases produce which return.

**Required form:**

```java
/**
 * One-line summary in imperative mood ("Updates the employee…", NOT "Updates…").
 * Optionally one more sentence for context.
 *
 * @param id     employee id; must exist.
 * @param update writable fields; non-null.
 * @return the updated record.
 * @throws AppException when the employee is not found (ErrorReason.C001).
 */
public EmployeeRecord update(Long id, EmployeeUpdate update) { … }
```

**Records:** document each component in the class-level Javadoc using the
`@param` tag (Java treats record components as constructor parameters):

```java
/**
 * A single page of results plus the total match count.
 *
 * @param items the records on this page.
 * @param total total matching records across all pages.
 */
public record PageRecord<T>(java.util.List<T> items, long total) {}
```

**Skip Javadoc only for:** generated code, `@Override` of an already-documented
parent (Javadoc inherits), trivial getters/setters synthesised by Lombok, and
private methods shorter than 3 non-blank lines.

**Private methods longer than 3 lines** also MUST carry Javadoc — that's
where complexity hides and edits drift silently. Document WHY (not WHAT),
edge cases, sentinel returns, what the method explicitly does NOT do.

Enforced by Checkstyle (`MissingJavadocMethod` scope=public, `JavadocMethod`
validates `@param`/`@return`/`@throws` correspondence).

## Port architecture lock (hard reject if violated)

ONE public port: backend `5000` → externalPort `80`. Vite is workspace
preview only. Prior runs swapped Vite onto 5000 + Spring to 8080 — breaks
Reserved-VM Deployment (one port only); user sees dev server instead of
Spring serving the production React bundle.

| Surface | Port | Notes |
|---|---|---|
| Spring Boot | **5000** | `${PORT:5000}` in `application-replit.yml`; `.replit` `[env]` `PORT="5000"` |
| `.replit` `[[ports]]` (single) | `5000 → 80` | Reserved-VM Deployment supports ONE externalPort |
| Vite dev server | **5173** | Workspace preview only — auto-detected by Replit pane, NO `[[ports]]` entry (would try to expose 5173 in deployment where Vite isn't running) |
| Production frontend | served by backend | `npm run build` → `backend/application/src/main/resources/static/` |

**Hard rules:**
- Never Vite=`5000`, never Spring=`8080` on `replit` profile.
- Never run `spring-boot:run` on the parent reactor. `.replit` must first
  `mvn -f backend/pom.xml -DskipTests -Dskip.frontend=true install`, then run
  `mvn -f backend/application/pom.xml -DskipTests -Dskip.frontend=true spring-boot:run`.
- Never start Vite before `npm run generate:api`; missing generated types mean
  the frontend was booted against a stale or absent OpenAPI schema.
- Never invent root `start.sh` — `.replit` parallel tasks run the two commands above + `npm run dev`.
- Never hard-code `server.port: 8080` in `application-replit.yml` — keep `${PORT:5000}`.
- `application-replit.yml` MUST set `spring.datasource.url`, `username`, and
  `password` directly from Replit's `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`,
  `PGPASSWORD` env vars. Do not add a custom DataSource bean or an
  `EnvironmentPostProcessor`. Do not force `sslmode=require`; current Replit
  Postgres connections work without SSL unless the actual env explicitly says
  otherwise.

Tempted to "swap Vite onto 5000 so the webview shows the UI"? Stop. On
Deployment the UI is Spring serving the BUILT React from `/static/`.

## OpenAPI-first delivery

1. Update `openapi.yaml` first.
2. Make each changed operation tick the `openapi-review-checklist.md`.
3. Regenerate via `openapi-generator-maven-plugin`; implement generated interfaces.
4. Regenerate frontend types via `npm run generate:api` when a frontend exists.
5. Add tests for contract compliance.

Never handwrite DTOs that duplicate generated schemas.

## Runtime: Replit vs local-dev

| | Replit | Local-dev |
|---|---|---|
| Spring profile | `replit` | `local` |
| PostgreSQL | Replit SQL DB via `PGHOST`/`PGPORT`/`PGDATABASE`/`PGUSER`/`PGPASSWORD`; no forced SSL; Hikari `2–3` | docker-compose; Hikari `50` |
| Server port | `5000` → external `80` | `8080` |
| Build | Maven via `.replit` Run | Maven or `docker compose --profile local up --build` |
| Deployment | Reserved VM (`gce`) | n/a |

Baseline: `references/hikari-jpa-baseline.yml` — copy into `application.yml`,
override only context-path and profile-specific DS vars. Replace
`/some-path-by-app-name` with the real context path.

## Auth, usage logging, L2 cache

This skill enforces:
- Backend deps `spring-boot-starter-oauth2-resource-server` (SSO/auto) +
  `spring-boot-starter-aop` when the active project actually needs an aspect.
- While `backend/event-logging-to-db-feature/` exists, usage logging writes to
  `usage_events` via its bundled Liquibase changelog;
  `NoOpUsageLogger` binds when `USAGE_LOGGING_ENABLED=false`.
- Usage logging is **automatic**: the aspect intercepts every public
  `*ServiceImpl` method (no annotation needed). `@LogUsage(action = "...")` is
  an OPTIONAL override for the derived `<aggregate>.<method>` action name.
  Manual `logger.record(...)` in business code is forbidden. If the module is
  absent after handoff, do not recreate any of these types automatically.
- If caching is selected, L2 cache is application-level JCache/Ehcache:
  Hibernate L2/query cache,
  `hibernate-cache` region prefix, `missing_cache_strategy: fail`, and explicit
  regions in `ehcache.xml`. Spring and Hibernate share one manager.
  Service-level `ConcurrentMapCacheManager` is forbidden. If no application
  cache exists, the complete cache stack should remain absent.
- Mutable cached sources use the DB-backed monotonic-ID outbox described in
  `.claude/agent_docs/distributed_cache.md`. Publication belongs in the same
  transaction as the write; timestamp cursors and after-commit in-memory events
  are forbidden.

Full contracts: references table above.

## Database types

See `.claude/agent_docs/database_schema.md`.

## No magic values (mandatory)

Business literals come from ONE of:
1. Java enum with fields (`code`, `displayName`, optional flags) for persisted
   statuses, roles, scopes, claim names, error codes, and other semantic values.
2. `@ConfigurationProperties` bean for environment/runtime settings.
3. `public static final` constant only when Java/Spring requires a compile-time
   constant (annotation attributes, logger names, public path arrays).
3. OpenAPI YAML for HTTP status + error shapes.

Forbidden:
- `if (mode.equals("sso"))` — use the constant.
- Inline HTTP status numbers — use `HttpStatus.NOT_FOUND`, not `404`.
- Magic `@Table(name = "employees")` — define `static final String TABLE = "employees"`.
- Magic timeouts — externalise via `@ConfigurationProperties` (never `@Value`).

## Testing (MVP safety suite + handoff)

Full policy: `templates/generated-project/testing/testing-policy.md`.

Stack: JUnit 5 + Mockito + AssertJ + Spring Boot Test. Given/When/Then.
`IT` suffix for integration tests. REST via `@WebMvcTest` or `@SpringBootTest`
with a Clerk JWT supplied by Spring Security's `jwt()` test post-processor.

Phases:
1. **Building** — no completion claim yet; `-DskipTests` is allowed only for
   internal compile/debug loops while the app is not runnable. Phase-aware
   verification still enforces the non-zero `mvp` floor.
2. **MVP safety suite** — Phase 1 exit = build succeeds + app boots +
   `/auth/me` 200 + one endpoint reads DB + frontend renders. Before final
   response/publish, add backend safety tests: app/health smoke, auth boundary,
   main happy path, main error contract, service unit tests, Liquibase smoke
   when persistence exists. Coverage ratchets after tests exist.
3. **Handoff** — set `.template-phase` to `engineering`; then
   `bash scripts/local-verify.sh` enforces the strict `0.80`/`0.70` defaults
   plus Testcontainers integration tests.

**Phase 1→2 transition is non-negotiable.** Prior generations skipped Phase 2,
shipped with zero tests. The MOMENT exit criteria are met, switch mode; don't
accept further feature prompts until Phase 2 done. Min bar: every controller
has an auth/contract test AND every `*ServiceImpl` public method has one unit
test. `mvp-safety-review` REJECTS publish if backend tests are missing while
controllers/services exist.

User says "ship without tests, demo Friday"? Surface the risk; proceed only
after written confirmation.

### Phase 2 minimums per endpoint

- Service happy-path + main negative `AppException` branch (unit + Mockito).
- Controller success + 401 (no token) + 403 (wrong role) + 400 (validation) via `@WebMvcTest`.
- One Liquibase smoke (`@DataJpaTest` or Testcontainers) running master changelog.
- One application/health smoke for the generated backend.

## Build flags: what you may and may not skip

| Flag | Allowed? | Why |
|---|---|---|
| `-DskipTests` | ✅ Phase 1 only | Tests rewritten on implementation churn |
| `-Dcheckstyle.skip=true` | ❌ NEVER | Runs in <2s; fix violation |
| `-Djacoco.skip=true` | ❌ NEVER | Disables coverage gathering |
| `-Dmaven.test.skip=true` | ❌ NEVER | Skips COMPILATION — broken tests vanish. Use `-DskipTests` |
| `-Dopenapi.skip=true` | ❌ NEVER | Controllers implement generated interfaces |
| `-Dgit-commit-id.skip=true` | ✅ Anytime without `.git` | Scaffold default |

CI runs `mvn verify` without forbidden flags; local bypass delays failure.

## Spring Boot gotchas (lookup table)

Fixes in `references/spring-boot-gotchas.md` — open the moment you hit the
symptom. Do NOT improvise alternative fixes.

| Symptom | Where to look |
|---|---|
| Build fails with `TypeTag :: UNKNOWN` | TypeTag UNKNOWN (Lombok/JDK mismatch) |
| OAuth2 resource-server crashes at startup with empty `issuer-uri` | OAuth2 Resource Server auto-config |
| `requestMatchers("/<context-path>/...")` matches nothing | Spring Security `requestMatchers` |
| `/` or `/login` returns 401 after React build | Spring Security `requestMatchers` |
| Frontend hits `/api/v1/...` and gets 404 from Spring | OpenAPI `servers` not applied to controllers |
| `LazyInitializationException` in `mapper.toDto(...)` | Lazy init — map entity to record inside a transactional service and use a purpose-built fetch/projection |
| Postgres `bytea` error on JPQL `LOWER(CONCAT('%', :search, '%'))` | JPQL bytea crash |
| Tempted to use `JdbcTemplate` "for speed" | Don't mix JdbcTemplate with JPA |
| Datasource works in shell but Spring cannot connect | Replit datasource env wiring |
| Compile mismatch `OffsetDateTime` vs `LocalDateTime` | Time types — `LocalDateTime` only |
| Controller "fixes" generated interface by adding `@AuthenticationPrincipal` or calls `getRequest()` | Generated OpenAPI interface signatures |
| Export endpoint returns `byte[]` or wrong generated type | OpenAPI binary exports use Spring `Resource` |
| Logbook `DefaultSink` constructor compile error | Logbook 3.x sink needs formatter + writer |
| Checkstyle complains about static final `log` | Use explicit `private static final Logger LOG` |
| `git-commit-id` plugin failing in workspace without `.git` | git-commit-id blocking in Replit shell |
| Service signature returns `Entity` (lazy safe but module-bad) | Services still return Records, not Entities |
| Replit log says `spring-boot:run` is running on parent POM | Run install on parent, then `spring-boot:run` from `backend/application/pom.xml` |
| Vite says generated API types are missing | Run `npm run generate:api` before Vite in `.replit` |
| Frontend calls wrong path/method (`PATCH` vs `PUT`, `/usage/summary` vs `/admin/usage`) | Use only typed `apiClient`; raw fetch/axios is forbidden |

## Local-dev dry run

```bash
docker compose --profile local config
docker compose --profile local up --build -d
curl -f http://localhost:8080/<app-context-path>/actuator/health
curl -f http://localhost:8080/<app-context-path>/actuator/prometheus
docker compose --profile local down -v
```

Skip on Replit. If blocked, document exact reason + commands in README.
