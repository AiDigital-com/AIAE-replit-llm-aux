# Usage Logging Rules

This document applies while `backend/event-logging-to-db-feature/` is present
during the MVP feedback phase. After engineering handoff, treat the sections
below as historical design context; do not recreate the removed runtime unless
engineering explicitly selects a production analytics design.

While installed, one fire-and-forget event per meaningful user action goes to
the app's PostgreSQL `usage_events` table. A manager can query the table for
usage estimation.

One sink, one table, the same DB the app already uses.

## Module layout

The Java surface of the feature ships as a single Maven module:
`backend/event-logging-to-db-feature/`. That module owns the `@LogUsage`
annotation, the `UsageAttributes` helper, the `UsageEvent` value record,
the `UsageLogger` sink interface, both impls (`PostgresUsageLogger`,
`NoOpUsageLogger`), the `UsageLoggingAspect`, the `@ConfigurationProperties`
bean, and the JPA entity + repository. Java package root inside the module:
`<base>.usagelogging` (entity + repo live in `entities/` and
`repositories/` sub-packages). `service` depends on
`event-logging-to-db-feature` so `*ServiceImpl` classes can carry
`@LogUsage`; `application` picks it up transitively.

**Migrations stay in the `migrations` module.** The Liquibase changelog
`0001-usage-events.xml` lives at
`backend/migrations/src/main/resources/db/changelog/changes/0001-usage-events.xml`,
referenced from `db.changelog-master.xml` exactly like every other migration
in the project. Feature modules NEVER ship their own
`src/main/resources/db/` tree — splitting migrations across modules hides
the schema-change contract from the migration owner and makes cross-module
classpath includes a long-term footgun. One source of truth for the
schema; the feature module's `@Entity` simply maps the table the migration
creates. To disable: see "Disabling" below.

## Disabling

| Path | What it leaves behind |
|---|---|
| `app.usage-logging.enabled=false` (env `USAGE_LOGGING_ENABLED=false`) | `NoOpUsageLogger` binds; aspect drops via `@ConditionalOnProperty`; `usage_events` table stays; `@LogUsage` annotations stay as inert markers. **No code edits, no rebuild required.** |
| Engineering handoff removal | Run `bash scripts/prepare-engineering-handoff.sh --apply`. It invokes `remove-usage-logging.sh`, removes the module, safe `@LogUsage` call sites, configuration/environment entries, and the centralized `0001-usage-events.xml` migration, then verifies the application without the feature. Fresh schemas no longer create `usage_events`; an existing database is not modified automatically and requires an explicit retain/archive/drop decision. Semantic `UsageAttributes` or custom-sink usages block until the agent removes them deliberately. |

## Explicit UI action endpoint

When the frontend logs user actions explicitly by calling
`POST /api/v1/usage-events`, set `app.usage-logging.enabled=false` (or default
`USAGE_LOGGING_ENABLED=false`). That disables the AOP/service auto-logging
aspect so the same click/action is not recorded twice.

The explicit endpoint must write through the usage event sink directly. Do not
route explicit UI events through `UsageLogger`, because `UsageLogger` is the
AOP-facing abstraction that becomes `NoOpUsageLogger` when auto-logging is
disabled.

## Default behavior

Ships with `USAGE_LOGGING_ENABLED=true` + `PostgresUsageLogger`. Binding
rules at startup:

| `enabled` | `service-name` | Binds | Notes |
|---|---|---|---|
| `false` | (any) | `NoOpUsageLogger` | Explicit opt-out, silent by design |
| `true`  | non-empty, not placeholder | `PostgresUsageLogger` | Normal path |
| `true`  | **empty / blank / `replit-mvp-template`** | **FAIL FAST at startup** | Loud `IllegalStateException` — do NOT silently fall back to NoOp |

The fail-fast row is REQUIRED. Past sessions silently bound `NoOpUsageLogger`
on empty `service-name` and shipped projects with zero usage events to the
DB — the dashboard read as "0 actions" with no error anywhere. The right
behavior is loud refusal so the misconfiguration is impossible to miss.

The scaffold's `application.yml` defaults `service-name` to
`${spring.application.name}` so an unset env var still binds the logger.
During generation, set `APP_SERVICE_NAME` / `spring.application.name` to the
real service identifier before handoff.

Local dev + tests run without setup beyond the default `usage_events`
Liquibase changelog. Logger never blocks a request, never throws into the flow.

## Automatic vs. manual

**Automatic** (template wires it, don't reimplement):
- `spring-boot-starter-aop` → AspectJ proxying (no `@EnableAspectJAutoProxy`).
- `UsageLoggingAspect` is `@Aspect @Component`, scanned at startup.
- `@ConditionalOnProperty(name="app.usage-logging.enabled", matchIfMissing=true)`
  → aspect active by default; flip to `false` to silence without code change.
- Aspect handles success/exception/duration/user/correlationId. Business code
  never imports `UsageLogger`.

**Automatic — no annotation needed** (this is the key behavior):
- The aspect intercepts EVERY public method of EVERY `*ServiceImpl` (pointcut
  `execution(public * *..service..services.impl.*ServiceImpl.*(..))`). Usage
  logging can never be "forgotten" — there is nothing to annotate.
- The action name is derived as `<aggregate>.<method>` (e.g.
  `SampleServiceImpl#findById` → `sample.findById`).
- Private/internal helpers and self-invoked calls are not logged (Spring AOP
  proxy semantics — call service methods from another bean, e.g. the controller).

**Optional override** (`@LogUsage`):
- Add `@LogUsage(action = "<dotted.lowercase>")` on a method ONLY to override
  the derived action name (a stable analytics id — pick once; renaming breaks
  dashboard queries) or to set a non-default `eventType`.

Reference: `SampleServiceImpl` in scaffold.

## Required env placeholders (in `.env.example`)

```
USAGE_LOGGING_ENABLED=true
USAGE_LOG_SERVICE_NAME=generated-mvp
USAGE_LOG_ENVIRONMENT=dev
```

That is the entire usage-logging configuration surface.

For projects with explicit UI action ingestion, default
`USAGE_LOGGING_ENABLED=false` and keep the frontend's explicit event endpoint
enabled instead.

`USAGE_LOG_SERVICE_NAME` should be set to the actual service identifier before
handoff. `replit-mvp-template` is a recognisable rejected placeholder. When
`enabled=true` AND `service-name` is empty/blank/placeholder,
`UsageLoggingConfig` MUST throw `IllegalStateException` at startup with a
clear error message — do NOT silently bind `NoOpUsageLogger`. NoOp is
reserved for the explicit opt-out path (`enabled=false`).

## Event payload

Schema is intentionally **1:1 with the AI Digital BigQuery
`usage_logging_ai_services_table`** so a future BQ exporter can ship rows
without remapping. NOT NULL constraints follow BQ's REQUIRED set
(`event_id`, `event_timestamp`, `service`, `event_type`); everything else
is nullable so partial / fire-and-forget events still land.

| Field | Postgres type | Required | Notes |
|---|---|---|---|
| `event_id` | `TEXT UNIQUE` | yes | UUID v4 per event |
| `event_timestamp` | `TIMESTAMPTZ` | yes | UTC, ISO 8601 |
| `service` | `TEXT` | yes | stable lowercase hyphen-separated service name |
| `environment` | `TEXT` | no | `prod` / `staging` / `dev` |
| `event_type` | `TEXT` | yes | `api_request` / `auth` / `error` / `custom` |
| `action` | `TEXT` | no | dotted lowercase, e.g. `forecast.create` |
| `user_id` | `TEXT` | no | `Authentication#getName()`. `SecurityConfig` wires `JwtAuthenticationConverter#setPrincipalClaimName("user_id")`, so this is the stable Clerk `user_id`. **Never** the email address. |
| `user_email` | `TEXT` | no | normalized `email` claim, stored separately from the principal id |
| `status` | `TEXT` | no | `success` / `error` / HTTP code as string |
| `duration_ms` | `BIGINT` | no | operation latency |
| `attributes` | `JSONB` | no | sanitized structured payload — see "Per-row attributes" below |
| `error_message` | `TEXT` | no | short error description for failures |
| `client_ip` | `TEXT` | no | first `X-Forwarded-For` entry |
| `user_agent` | `TEXT` | no | request UA |

The BQ-aligned schema has no top-level `correlation_id` or `user_name`
column. The aspect lifts both into `attributes` JSON automatically:

- `attributes.correlation_id` — value of MDC `correlationId` at log time.
- `attributes.user_name` — first non-blank of `full_name` / `name` /
  `preferred_username` from the Clerk JWT. If none of those is set, the aspect
  composes `first_name + " " + last_name` (Clerk template variables) as a
  fallback. Skipped only when no naming claim is present at all.

Query example:
```sql
SELECT attributes->>'user_name' AS name, COUNT(*)
FROM usage_events
WHERE event_timestamp > now() - interval '7 days'
GROUP BY 1
ORDER BY 2 DESC;
```

## Per-row attributes

`attributes` (JSONB) is the catch-all. The aspect always seeds the
auto-lifted keys above; on top of that, business code adds domain-specific keys by injecting `UsageAttributes` and
calling `usageAttributes.put(...)` from inside the service method:

```java
private final UsageAttributes usageAttributes;

@LogUsage(action = "forecast.create")
public ForecastRecord create(ForecastRequest req, AppUser caller) {
    usageAttributes.put("geo", req.geo());
    usageAttributes.put("channel", req.channel());
    return ...;
}
```

Rules:
- `UsageAttributes` is ThreadLocal — works for synchronous controller →
  service calls (the common path). For `@Async` methods, use
  `SecurityContextHolder.MODE_INHERITABLETHREADLOCAL` /
  `DelegatingSecurityContextRunnable` and the same applies here.
- The aspect drains the bag inside its `finally{}` and clears it; the next
  request on the same worker thread starts clean.
- Values must be JSON-serialisable (`String`, `Number`, `Boolean`,
  `Map`, `List`). Hibernate maps the column with
  `@JdbcTypeCode(SqlTypes.JSON)` + Jackson.
- **Never PII**: emails of third parties, raw doc bodies, credentials,
  full request/response payloads, JWTs. Same rule as for the BQ-shared
  table — see "Sensitive data" below.

## Java backend contract — AOP-driven, single annotation

Wired via Spring AOP aspect — **no explicit `logger.record(...)` calls in
business code**. Methods to track get `@LogUsage(action = "...")`;
`UsageLoggingAspect` does the rest. Both success and exception paths captured
by one `try/catch/finally` in the aspect. Disable globally via
`app.usage-logging.enabled=false`.

### Components

- `LogUsage` annotation (`@Retention(RUNTIME) @Target(METHOD)`) carrying
  `action` (mandatory, dotted lowercase like `employee.update`) and
  `eventType` (default `api_request`). Lives in
  `backend/event-logging-to-db-feature/src/main/java/<base>/usagelogging/LogUsage.java`.
  `*ServiceImpl` classes import it via `import <base>.usagelogging.LogUsage;`
  — `service` depends on `event-logging-to-db-feature` for exactly this reason.
- `UsageLoggingAspect` — `@Aspect @Component @Order(LOWEST_PRECEDENCE - 100)`,
  bound to `@annotation(logUsage)`, wraps target with `try/catch/finally`.
- `UsageLoggingProperties` — `@ConfigurationProperties("app.usage-logging")`
  binding `enabled`, `service-name`, `environment`. NO magic strings.
- `UsageEvent` — immutable value type (`@Builder` Lombok record), in
  `<base>/usagelogging/UsageEvent.java`. Service classes don't construct
  it directly; the aspect does.
- `UsageEventEntity` — JPA `@Entity` on `usage_events`, lives in
  `<base>/usagelogging/entities/`.
  **The `attributes` field MUST be declared as
  `Map<String, Object>` with `@JdbcTypeCode(SqlTypes.JSON)` +
  `@Column(columnDefinition = "jsonb")` — Hibernate 6 native JSON mapping.**
  Declaring it as `String` binds null as `varchar`, and Postgres rejects:
  `column "attributes" is of type jsonb but expression is of type character
  varying`. Past sessions burned hours on exactly this error.
- `UsageEventRepository extends JpaRepository<UsageEventEntity, Long>`,
  lives in `<base>/usagelogging/repositories/`.
- `UsageLogger` — interface, single method `void record(UsageEvent event)`.
  Lives in `<base>/usagelogging/UsageLogger.java`; impls
  (`PostgresUsageLogger`, `NoOpUsageLogger`) sit alongside it in the same
  module so the whole feature ships as one cohesive unit.
- `PostgresUsageLogger` — thin dispatcher only. It calls
  `UsageEventPersistenceService.persist(event)`. It does NOT save directly
  and does NOT own `@Transactional`; otherwise Spring proxying is bypassed.
- `UsageEventPersistenceService` — separate Spring bean that owns the actual
  insert. Method `persist(UsageEvent)` MUST be annotated with both
  `@Async("usageLoggingExecutor")` and
  `@Transactional(propagation = Propagation.REQUIRES_NEW)`, then catch/log/drop
  any insert failure.
- `NoOpUsageLogger` — bound only when `enabled=false`.

### Critical invariants (preserve on every edit)

1. **Self-invocation does NOT trigger the aspect.** Spring AOP uses proxies;
   `this.method()` inside the same bean bypasses the proxy. Always call
   the `@LogUsage`-annotated method from another bean (controller calling
   service is the canonical case).
2. **Aspect order is `LOWEST_PRECEDENCE - 100`** — strictly OUTER than
   Spring's `@Transactional` (`LOWEST_PRECEDENCE`). Usage event is logged
   AFTER the controller's transaction commits/rolls back; the `status`
   field reflects the final outcome.
3. **Persistence service is `@Async` + `REQUIRES_NEW`** — the aspect hands
   off the event and returns immediately. The INSERT runs in a separate Spring
   proxy and a separate transaction, so it is not bound to a controller's
   read-only transaction or rollback.
4. **No raw args** — the aspect deliberately ignores `joinPoint.getArgs()`.
   `action`/`eventType` from the annotation + auth context + duration +
   status is the entire payload. Anything sensitive is unreachable through
   this path.
5. **MDC correlationId** is captured via `MDC.get("correlationId")`. A
   request filter (Logbook or your own) must populate it earlier in the chain.
6. **`@Aspect` bean is `@ConditionalOnProperty(name="app.usage-logging.enabled", havingValue="true", matchIfMissing=true)`**
   — set `app.usage-logging.enabled=false` to disable globally without
   touching code.

### Usage at call sites

```java
@Service
@RequiredArgsConstructor
public class ResourceServiceImpl implements ResourceService {

    private final ResourceRepository repo;
    private final ResourceMapper mapper;

    @Override
    @LogUsage(action = "resource.update")
    public ResourceRecord update(Long id, ResourceUpdate update, AppUser caller) {
        ResourceEntity entity = repo.findById(id)
            .orElseThrow(() -> new AppException(ErrorReason.C001, id));
        entity.apply(update);
        return mapper.toRecord(repo.save(entity));
    }
}
```

That's the entire integration. The aspect captures: action `resource.update`,
duration of the call, success or error (with truncated message), the
authenticated user from `SecurityContext`, the correlationId from MDC.

### Async + SecurityContext caveat

`SecurityContextHolder` is `ThreadLocal`. If the `@LogUsage` method is itself
`@Async`, set at startup:

```java
SecurityContextHolder.setStrategyName(SecurityContextHolder.MODE_INHERITABLETHREADLOCAL);
```

Or use `DelegatingSecurityContextRunnable`. Not needed for synchronous
controller→service (common path).

**Why JPA, not JdbcTemplate.** Codebase uses JPA; mixing = two persistence
paths to maintain. JPA `save()` single insert is fast enough; async wrapper
keeps it off the request path.

Binding rule (Spring `@Configuration`, no magic strings):

```java
@Configuration
@EnableAsync
public class UsageLoggingConfig {

    @Bean
    @ConditionalOnProperty(name = "app.usage-logging.enabled", havingValue = "true")
    @ConditionalOnProperty(name = "app.usage-logging.service-name")
    UsageLogger postgresUsageLogger(UsageEventPersistenceService persistenceService,
                                    UsageLoggingProperties props) {
        return new PostgresUsageLogger(persistenceService);
    }

    @Bean
    UsageEventPersistenceService usageEventPersistenceService(UsageEventRepository repo) {
        return new UsageEventPersistenceService(repo);
    }

    @Bean
    @ConditionalOnMissingBean(UsageLogger.class)
    UsageLogger noOpUsageLogger() {
        return new NoOpUsageLogger();
    }
}
```

Implementation rules for `PostgresUsageLogger`:
- `record(UsageEvent)` delegates to `UsageEventPersistenceService.persist(event)`.
- No direct repository field and no `repo.save(...)` in `PostgresUsageLogger`.
- No `@Async` or `@Transactional` on `PostgresUsageLogger.record`; these must
  live on the separate persistence bean so Spring proxying applies.

Implementation rules for `UsageEventPersistenceService`:
- `@Async("usageLoggingExecutor")` and
  `@Transactional(propagation = Propagation.REQUIRES_NEW)` on `persist`.
- Inside the method body: `repo.save(toEntity(event))` wrapped in
  `try/catch (Throwable)`. On failure: log via SLF4J, **swallow** — never
  rethrow into the request flow.
- Provide a `TaskExecutor` bean `usageLoggingExecutor` with a bounded queue
  (e.g. `ThreadPoolTaskExecutor` with `corePoolSize=1, queueCapacity=200`)
  + `RejectedExecutionHandler` that logs+drops.
- Never `@Transactional` on `UsageLoggingAspect` / `@Around` advice. Spring
  applies transactions via proxies; advice methods are not called through the
  controller's proxy. Past generated apps inherited the controller's read-only
  transaction and blocked INSERTs. The separate persistence bean is mandatory.

### Auth principal coverage

The aspect's `extractEmail` reads the principal — always a Clerk
`org.springframework.security.oauth2.jwt.Jwt` (Clerk SSO is the only auth
mode) — walking a fixed list of claim names (`email`, `email_address`,
`primary_email_address`, `mail`; first hit wins) via
`jwt.getClaims().get(<name>)`. It populates only if the Clerk JWT carries an
email claim — Clerk-side JWT-template configuration is out of scope here. The
multi-claim fallback is defensive against varied IdP claim naming and adds no
provider-side requirement.

## Liquibase changelog

Lives at `backend/migrations/src/main/resources/db/changelog/changes/0001-usage-events.xml`,
referenced from `db.changelog-master.xml` like every other migration.
The feature module owns the `@Entity` that maps the table, but the
schema-change contract sits in `migrations/` — that's the project-wide rule.

```xml
<changeSet id="usage-events-initial" author="agent">
  <createTable tableName="usage_events">
    <column name="id" type="BIGINT" autoIncrement="true">
      <constraints primaryKey="true" nullable="false"/>
    </column>
    <column name="event_id"         type="TEXT"        ><constraints nullable="false" unique="true"/></column>
    <column name="event_timestamp"  type="TIMESTAMPTZ" ><constraints nullable="false"/></column>
    <column name="service"          type="TEXT"        ><constraints nullable="false"/></column>
    <column name="environment"      type="TEXT"        />                                <!-- BQ NULLABLE -->
    <column name="event_type"       type="TEXT"        ><constraints nullable="false"/></column>
    <column name="action"           type="TEXT"        />                                <!-- BQ NULLABLE -->
    <column name="user_id"          type="TEXT"        />
    <column name="user_email"       type="TEXT"        />
    <column name="status"           type="TEXT"        />                                <!-- BQ NULLABLE -->
    <column name="duration_ms"      type="BIGINT"      />
    <column name="attributes"       type="JSONB"       />                                <!-- BQ JSON; includes correlation_id -->
    <column name="error_message"    type="TEXT"        />
    <column name="client_ip"        type="TEXT"        />
    <column name="user_agent"       type="TEXT"        />
  </createTable>

  <createIndex tableName="usage_events" indexName="idx_usage_events_service_ts">
    <column name="service"/>
    <column name="event_timestamp" descending="true"/>
  </createIndex>
  <createIndex tableName="usage_events" indexName="idx_usage_events_action_ts">
    <column name="action"/>
    <column name="event_timestamp" descending="true"/>
  </createIndex>
</changeSet>
```

## Instrumentation

Log:
- successful user actions
- failed user actions (same `action` value as the success path)
- auth login/logout when applicable
- important custom domain actions

Skip:
- `/health`, `/actuator/*`
- `OPTIONS` requests
- browser prefetches, static assets
- internal readiness/liveness probes

## Sensitive data

Never write to `attributes`, `error_message`, or app logs:
credentials, API keys, JWTs, service account JSON, raw document contents,
full request/response bodies, third-party PII, private URLs.

Keep `attributes` small and structured. Strip raw user content over ~500 chars.

## Acceptance check

```sql
-- Recent activity for a service
SELECT event_timestamp, service, action, user_email, status, duration_ms
FROM usage_events
WHERE service = '<your-service-name>'
ORDER BY event_timestamp DESC
LIMIT 10;

-- Manager estimation: action counts over the last 7 days
SELECT action, COUNT(*) AS n
FROM usage_events
WHERE event_timestamp > now() - interval '7 days'
GROUP BY action
ORDER BY n DESC;
```

## Manager workflow: build a dashboard with Replit

Replit's [Create a dashboard from data](https://docs.replit.com/build/dashboard)
turns any data source into a small visualization app. Manager uses it on the
**same DB** the MVP writes to.

### Cross-app DB sharing

`postgresql-16` provisions a SQL Database **per app**. Dashboard app is
separate → does NOT auto-share MVP's DB. Two options:

**Option 1 — manual connection string (simplest).**
1. Copy MVP app's `DATABASE_URL` from Replit Secrets.
2. Create read-only role on MVP's DB (`usage_reader`, see below); build a
   connection string with its credentials (not superuser).
3. Paste read-only URL as `DATABASE_URL` in the dashboard app's Secrets.

**Option 2 — shared external DB** (only for cross-service aggregation).
Managed Postgres outside Replit (Neon, RDS); both apps' `DATABASE_URL` point
to it. Triggers the BigQuery migration revisit below.

### Manager flow (Option 1)

1. "Create a dashboard from data" in Replit.
2. Paste read-only `DATABASE_URL`.
3. Describe the view in plain language (e.g. "action counts per day, top users
   by action volume, error-rate trend, filter by service and date range").
4. Agent generates the dashboard; manager bookmarks the URL.

Dashboard is independent of MVP — reads `usage_events` only. Service code
stays free of dashboard UI.

### Read-only manager role

Run once against the MVP's DB (using the superuser `DATABASE_URL`):

```sql
CREATE ROLE usage_reader LOGIN PASSWORD '<strong-random>';
GRANT CONNECT ON DATABASE <db> TO usage_reader;
GRANT USAGE ON SCHEMA public TO usage_reader;
GRANT SELECT ON usage_events TO usage_reader;
```

Then build the dashboard's `DATABASE_URL` as:
```
postgresql://usage_reader:<password>@<host>:<port>/<db>
```

## Future migration (only when needed)

For cross-service aggregation, add a second `UsageLogger` impl writing to
the aggregation target (e.g. BigQuery); bind instead of `PostgresUsageLogger`.
Event payload is portable — adding a sink is implementation-only, no contract changes.
