# Spring Boot common gotchas (real failures from past generations)

Read BEFORE writing controllers, security config, or any DataSource hook.
The main `SKILL.md` has a one-line summary; long fixes live here.

## Replit datasource env wiring

Past scaffold versions used `ReplitDatabaseUrlPostProcessor` and registered it
via `META-INF/spring/org.springframework.boot.env.EnvironmentPostProcessor.imports`.
That is the wrong hook for Spring Boot 3.x: `EnvironmentPostProcessor` still
requires `META-INF/spring.factories`; `.imports` is for auto-configuration.

Do not add the post-processor back. Generated apps configure the Replit profile
directly from env vars:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://${PGHOST:${POSTGRES_HOST:localhost}}:${PGPORT:${POSTGRES_PORT:5432}}/${PGDATABASE:${POSTGRES_DB:app}}
    username: ${PGUSER:${POSTGRES_USER:app}}
    password: ${PGPASSWORD:${POSTGRES_PASSWORD:app}}
```

Do not force `sslmode=require`. Real Replit Postgres instances have been seen
working without SSL, and forcing SSL broke app startup.

## OAuth2 Resource Server auto-config triggers on empty properties

`spring-boot-starter-oauth2-resource-server` on classpath → auto-config triggers
even when `spring.security.oauth2.resourceserver.jwt.issuer-uri` is empty.
Tries to fetch JWKS from empty URL → startup crash.

Fix (both required):
1. Always provide `@Bean JwtDecoder`. Scaffolded `SecurityConfig` provides the
   Clerk-SSO decoder (`@ConditionalOnMissingBean`, fail-fast if unconfigured).
2. Do NOT put `spring.security.oauth2.resourceserver.jwt.*` in `application.yml`.
   Scaffolded `application.yml` omits them — don't add "for completeness".

## Spring Security `requestMatchers` does NOT include the context path

`server.servlet.context-path: /my-app` + `requestMatchers("/my-app/api/v1/...")`
→ matches nothing. Spring Security strips context path BEFORE matching.

→ Path literals in `requestMatchers` look like `/api/v1/auth/me`, never
`/<context-path>/api/v1/auth/me`. See `AuthConstants.PUBLIC_PATHS`.

Spring also protects the React shell unless you explicitly permit it. Keep these
public when Spring Boot serves the built SPA:

```text
/
/index.html
/assets/**
/login
/login/**
/*.css
/*.js
/*.png
/*.svg
```

Backend APIs stay protected by default. When adding a new BrowserRouter route,
add the route shell to `PUBLIC_PATHS` if it must load before the frontend can
decide whether to redirect to login.

## OpenAPI `servers: [{ url: /api/v1 }]` is NOT applied to controllers

The OpenAPI generator does NOT prepend `servers` URL to `@RequestMapping`
on generated interfaces. Interface declares `/auth/me`; frontend client sends
to `/api/v1/auth/me`; Spring MVC 404s.

Three remedies (scaffold uses #1):

1. **Class-level `@RequestMapping("/api/v1")` on every controller.** Required
   if `/api/v1` stays the wire URL without changing `application.yml`.
2. **`server.servlet.context-path: /api/v1`** + strip `/api/v1` from `servers`.
   Cleanest with one API base path.
3. **Inline `/api/v1` in every YAML path** + remove `servers`. Verbose YAML, no Java trickery.

Stay consistent across the project.

## Generated OpenAPI interface signatures are exact

When `openapi-generator-maven-plugin` emits `*Api`, the controller method
signature must match it exactly. Do not add convenience parameters that are
not in the generated interface:

```java
// WRONG: generated interface has no Jwt parameter
public ResponseEntity<EmployeeV1> getEmployee(Long id, @AuthenticationPrincipal Jwt jwt)

// WRONG: many generated interfaces have no getRequest() helper
getRequest().ifPresent(...)
```

Canonical fixes:
- caller identity: `SecurityContextHolder.getContext().getAuthentication()`
  inside the controller, then `AppUserFactory.from(auth)`;
- request metadata: prefer filters/aspects (`CorrelationIdFilter`,
  `UsageLoggingAspect`); if a controller truly needs it, inject
  `HttpServletRequest` as a field/constructor dependency, not as a generated
  method parameter;
- exports/downloads: express the response in OpenAPI as binary content so the
  generated method returns `ResponseEntity<Resource>`.

CI rejects `@AuthenticationPrincipal` and `getRequest()` in hand-written
application controllers.

## Binary exports return Spring `Resource`

For CSV/XLSX/PDF/file exports, the OpenAPI response schema must be
`type: string`, `format: binary`, with the real media type. The generated Spring
interface then uses `org.springframework.core.io.Resource`.

```yaml
/api/v1/employees/export:
  get:
    operationId: exportEmployees
    responses:
      "200":
        description: CSV export.
        headers:
          Content-Disposition:
            schema: { type: string }
            example: attachment; filename="employees.csv"
        content:
          text/csv:
            schema:
              type: string
              format: binary
```

Controller shape:

```java
public ResponseEntity<Resource> exportEmployees() {
    ByteArrayResource body = new ByteArrayResource(service.exportCsv());
    return ResponseEntity.ok()
        .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"employees.csv\"")
        .contentType(MediaType.parseMediaType("text/csv"))
        .body(body);
}
```

Do not return `ResponseEntity<byte[]>`, `String`, or call `getRequest()` to
manually push bytes. Let the generated contract drive the type.

## `openapi-fetch` baseUrl must not duplicate `/api/v1`

The frontend schema keys are the literal OpenAPI paths. If the spec has
`/api/v1/auth/me`, this call:

```ts
createClient<paths>({ baseUrl: "/api/v1" })
apiClient.GET("/api/v1/auth/me", ...)
```

hits `/api/v1/api/v1/auth/me`. The API looks broken even though curling the
backend endpoint works.

Fix: `baseUrl` is empty by default. Use it only for a host or servlet context
prefix, e.g. `/employee-directory`, never `/api/v1`.

## `LazyInitializationException` — keep entities inside the transaction

JPA closes session at end of `@Transactional`; lazy fields touched after
throw. Past Agent runs crashed on `mapper.toDto(entity)` after service
returned an entity.

**Canonical rule**: controllers stay non-transactional. Service methods own the
narrow database boundary and return fully initialized records, never entities.

- Read services use `@Transactional(readOnly = true)` where a transaction is
  required for explicit fetch/mapping.
- Write services use `@Transactional` around database work only.
- External HTTP/SDK/storage/AI calls run outside the transaction; an
  orchestrator calls separate transactional collaborators before/after.
- Fix lazy access with a purpose-built projection, entity graph, fetch query, or
  mapping inside the service transaction. Do not switch associations to eager.

```java
@RestController
@RequiredArgsConstructor
class <Domain>Controller implements <Domain>Api {
    private final <Domain>Service service;
    private final <Domain>ApiMapper mapper;

    @Override
    public ResponseEntity<<Domain>V1> get<Domain>(Long id) {
        return ResponseEntity.ok(mapper.toDto(service.findById(id)));
    }

    @Override
    public ResponseEntity<<Domain>V1> update<Domain>(Long id, Update<Domain>RequestV1 req) {
        return ResponseEntity.ok(mapper.toDto(service.update(id, req)));
    }
}
```

The service loads/fetches and maps `Entity -> ServiceRecord` before returning.
The controller maps only `ServiceRecord -> ApiDto`, so MVC serialization never
touches a lazy entity and a slow client/external dependency cannot extend the
database transaction.

`@EntityGraph` / `JOIN FETCH` / `EAGER` are PERFORMANCE tools (kill N+1).
Not lazy fixes — the rule above already prevents that.

## Services still return Records, not Entities

Independent of `@Transactional` location: service signatures return
`ServiceRecord` (immutable), never JPA entities. Reason now is module
boundaries (not lazy safety) — entities leaking from `service/` lets
`application/` import JPA-aware types, breaking the dependency matrix.

## JPQL `LOWER(CONCAT('%', :search, '%'))` Postgres `bytea` crash

When `:search` is `null`/untyped, Hibernate may bind as `bytea` → Postgres
rejects the concat/LIKE expression. This appears in optional filters like
`(:nameSearch IS NULL OR LOWER(e.name) LIKE ...)`.

Preferred fix: build the pattern in Java, pass as single `String`:

```java
String pattern = (search == null || search.isBlank()) ? "%" : "%" + search.toLowerCase() + "%";
return repo.findByNameLike(pattern);
```

JPQL becomes `WHERE LOWER(e.name) LIKE :pattern`.

If the query must keep nullable params in JPQL, cast every nullable String
parameter at the point of use:

```java
@Query("""
    select e
    from EmployeeEntity e
    where (:nameSearch is null
        or lower(e.fullName) like lower(concat('%', cast(:nameSearch as string), '%')))
    """)
List<EmployeeEntity> search(@Param("nameSearch") String nameSearch);
```

Do not write `LOWER(CONCAT('%', :search, '%'))` with a nullable param. Either
pass a prebuilt `String` pattern or use `cast(:search as string)` consistently
in `LIKE`, `LOWER`, and `CONCAT` expressions.

## `@Around` advice transaction is not a persistence transaction

`@Transactional` on an aspect advice method is a trap. Spring applies
transactions through proxies, while the advice runs inside the intercepted
call. If an intercepted service is `@Transactional(readOnly = true)`, the
aspect can share that read-only tx and inserts fail or disappear.

Usage logging therefore uses a separate bean:

```java
class PostgresUsageLogger implements UsageLogger {
    private final UsageEventPersistenceService persistenceService;

    public void record(UsageEvent event) {
        persistenceService.persist(event);
    }
}

class UsageEventPersistenceService {
    @Async("usageLoggingExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void persist(UsageEvent event) { ... }
}
```

Never put `@Transactional` on `UsageLoggingAspect` or rely on repository
`save()` inside the advice.

## JSONB fields need Hibernate JSON mapping, not `String`

PostgreSQL `jsonb` columns must be mapped as structured JSON:

```java
@JdbcTypeCode(SqlTypes.JSON)
@Column(name = "attributes", columnDefinition = "jsonb")
private Map<String, Object> attributes;
```

Mapping `jsonb` as a plain `String` makes Hibernate bind `varchar`; Postgres
rejects inserts with `column is of type jsonb but expression is of type
character varying`.

## Role auth must not rely on the JWT `scope` claim

Spring's default `JwtGrantedAuthoritiesConverter` reads `scope`/`scp`. Mock
JWTs and many Clerk templates do not carry those claims. Result: login works,
admin endpoints return `403 insufficient_scope`.

When the app has roles/admin endpoints, configure a custom
`JwtAuthenticationConverter` that maps authorities from the application's
canonical role source (usually `user_roles` by lowercased email) into
`ROLE_*`. The JWT proves identity; the backend decides app roles.

## Don't mix `JdbcTemplate` with JPA

Whole stack is JPA. `JdbcTemplate` for "fast inserts" = two persistence
paths. Use `JpaRepository.save` from `@Async` (bounded `TaskExecutor`) for
fire-and-forget. See `observability/usage-logging-rules.md`.

## `com.sun.tools.javac.code.TypeTag :: UNKNOWN` (Lombok/JDK mismatch)

Build dies with `ExceptionInInitializerError: com.sun.tools.javac.code.TypeTag :: UNKNOWN`
→ old Lombok on new JDK. Lombok hooks internal javac APIs.

Fix sequence:

1. `mvn -version` — Replit's `pkgs.jdk21` puts JDK 21 on PATH. Different JDK?
   ```bash
   export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
   ```
2. JDK is correct → bump `${lombok.version}` in `backend/pom.xml`. Compatibility:
   1.18.30+ → JDK 21, 1.18.36+ → JDK 23, 1.18.40+ → JDK 24.
3. Also seeing MapStruct crashes? Add `lombok-mapstruct-binding` to the
   annotation processor path (parent pom `maven-compiler-plugin` config).

Do NOT:
- Delete `@RequiredArgsConstructor`/`@Getter`/`@Builder` (bug is in Lombok wiring).
- Switch to a different annotation processor.
- `<skip>true</skip>` annotation processors — MapStruct DTOs vanish.

## Time types: `LocalDateTime` only — do NOT change `dateLibrary`

Generator locked to `<dateLibrary>java8-localdatetime</dateLibrary>` (parent
pom). Every `format: date-time` → `java.time.LocalDateTime`. Project-wide,
non-negotiable.

Past failure: Agent saw `OffsetDateTime` vs `LocalDateTime` compile mismatch
and "fixed" by changing generator to `<dateLibrary>java8</dateLibrary>`.
**Wrong direction.** Generator is source of truth; hand-written code adapts.

On `incompatible types: LocalDateTime cannot be converted to OffsetDateTime`:
1. Change hand-written code, replace `OffsetDateTime`/`ZonedDateTime`/`Instant`
   field declarations with `LocalDateTime`.
2. Do NOT touch `<dateLibrary>` in `backend/pom.xml`.
3. Do NOT add `<typeMappings>OffsetDateTime=LocalDateTime</typeMappings>` —
   same anti-pattern, finer grain.

UTC convention (safety):
- DB: `TIMESTAMPTZ` storing UTC.
- Service/controller signatures: `LocalDateTime` interpreted as UTC.
- JSON wire: ISO-8601 string without offset (`2026-05-24T10:00:00`); document
  UTC in each OpenAPI field description.
- Frontend: treats as UTC, converts to local only at display.

User locale → separate timezone field; never embed in the timestamp.

## Lombok cascade failures in framework glue

Use Lombok for simple service/domain constructors, but avoid it in fragile
Spring framework glue where annotation-processing failures create misleading
compile errors.

Hard rules:
- `@ConfigurationProperties` classes use explicit getters/setters. Do not rely
  on Lombok-generated `getMock()`, `getSso()`, `getJwkSetUri()`, etc.
- Framework classes with loggers use explicit
  `private static final Logger LOG = LoggerFactory.getLogger(X.class);`.
  Do not use `@Slf4j`; do not name static final loggers `log` because Checkstyle
  requires `LOG`.
- If one logger is a business collaborator (`UsageLogger`), name it by purpose
  (`usageLogger`) so it cannot be confused with an SLF4J logger.
- Never import both `org.springframework.security.oauth2.jwt.JwtException` and
  `io.jsonwebtoken.JwtException`. Import Spring's exception, and use the JJWT
  type fully-qualified in the catch block.

## Logbook 3.x `DefaultSink` constructor

Logbook 3.x requires both formatter and writer:

```java
new DefaultSink(new JsonHttpLogFormatter(), new DefaultHttpLogWriter())
```

`new DefaultSink(new JsonHttpLogFormatter())` does not compile. Do not replace
the sink with text logging; services must emit structured JSON logs.

## Don't keep `git-commit-id-maven-plugin` blocking in Replit shell

Replit workspaces don't always have `.git`; plugin fails `mvn package`.
Scaffolded parent pom keeps `failOnNoGitDirectory=false` at plugin level so
both the named execution and Maven's default execution inherit it. In synthetic
CI copies without `.git`, also pass `-Dgit-commit-id.skip=true`.

Do NOT put `failOnNoGitDirectory=false` only inside one `<execution>` block:
Maven may still run a `default` execution in child modules and fail before the
rest of the reactor builds.

## Frontend path/method drift vs OpenAPI

Symptoms:
- Spec defines `/api/v1/auth/me` but the UI calls `/api/v1/auth/myself`.
- Admin usage is implemented at `/api/v1/admin/usage` but UI calls
  `/api/v1/usage/summary`.
- Spec says `put`, UI sends `PATCH`.

Root cause: frontend bypassed the generated OpenAPI path/method types, or Vite
started before `npm run generate:api`.

Fix:
1. Use only `shared/api/client.ts` (`openapi-fetch`) under `frontend/src`.
2. Run `npm run generate:api` before Vite/typecheck/build.
3. Let TypeScript reject invalid `apiClient.METHOD("/path")` combinations.
4. Keep local/CI grep guards forbidding raw `fetch`, `axios`, and
   `XMLHttpRequest`.

## Never swallow external-API error messages

Symptom: the UI shows an opaque `"X failed"` (e.g. "Google Slides deck creation
failed", "Failed to read tab \"Proposal\"") and the *actual* cause — no access,
bad input, resource not found — is only in the server log.

Root cause: a `catch` wraps the external exception but drops `ex.getMessage()`,
and/or the frontend replaces the backend's `ApiErrorV1.message` with a generic
string.

Fix (both layers):
1. **Backend** — when wrapping an external client exception (Google, an HTTP
   client, etc.), include the underlying detail in the `AppException` message.
   For typed errors, extract the clean field rather than the verbose
   `toString()` — e.g. `GoogleJsonResponseException.getDetails().getMessage()`
   plus the status code. Map common statuses (403/404) to an actionable hint
   ("share the sheet with the service account, or check the link") and still
   append the original detail.
2. **Frontend** — in the `openapi-fetch` wrapper, throw the backend
   `error.message` (the `ApiErrorV1` body), falling back to a clear sentence —
   never a bare `"Failed to <verb>"`. Let the toast render the real reason.

## Required external resource IDs must fail fast — no blank defaults

Symptom: an integration that "should work" returns an opaque downstream error
(404 / "deck creation failed") even though credentials are present.

Root cause: a **required** external id was shipped with a blank default
(`slides-template-id: ${SLIDES_TEMPLATE_ID:}`). Empty string is not "unset" — it
flows into the API call (`files.copy("")`) and Google returns a confusing 404.
The migration that "moved IDs to env vars" silently dropped the working
default.

Fix: for an id the feature cannot run without, either (a) ship a real, working
default in `application.yml`, or (b) validate it at startup / first use and fail
with a message that names the missing env var. Never let an empty required id
reach an external call. (Optional/best-effort ids — e.g. chart templates — may
stay blank since their failures are non-fatal warnings.)
