# Performance Engineering Rules

These rules prevent cross-layer load amplification in generated Spring Boot and
React applications. Apply them to the concrete workflow being changed; do not
treat them as a generic optimization checklist.

## Baseline and acceptance evidence

Map the workflow end to end:

```text
User action -> React query/mutation -> OpenAPI client -> controller -> service
-> repository/external client -> database -> response mapping -> React update
```

Before optimizing, capture the applicable baseline: browser request count,
backend latency, SQL count, response bytes, external-call duration, Hikari
occupancy, and Vite bundle output. A performance change is complete only when a
focused test or measurement shows the intended direction without correctness,
authorization, or user-behavior regression.

## Request, transaction, and concurrency rules

- Resolve the authenticated user and permissions once per request/workflow.
  Pass the resolved model through collaborators; do not repeat the same reads.
- Identity synchronization writes only when mapped fields changed. A protected
  read must not unconditionally update the user row.
- Database transactions contain database work only. External HTTP/SDK calls,
  object storage, AI calls, file transfer, polling, sleeps, and other slow I/O
  execute outside the transaction, with short explicit transactions around the
  before/after state transitions.
- Timeouts form a safe chain and retries are bounded, backed off/jittered, and
  limited to idempotent operations. Do not stack automatic frontend, backend,
  and SDK retries.
- Do not tune Hikari, servlet, async, scheduler, or HTTP pools independently.
  Measure request concurrency, database capacity, downstream limits, queues,
  and timeout behavior first.

## API, ORM, and SQL rules

- Every collection endpoint is bounded by pagination, an explicit limit, or a
  proven small invariant. List/card/table screens use summary contracts or
  projections and fetch detail only when opened.
- A multi-item user action uses one bulk endpoint and set-based repository work.
  Never implement it as sequential per-item requests plus repeated invalidation.
- No repository calls or lazy-association traversal inside loops. Batch IDs,
  use purpose-built queries/projections/entity graphs, and add a query-count
  regression test for the workflow.
- Fetch joins with pagination require an explicit correctness review for row
  multiplication, multiple bags, in-memory pagination, and count-query cost.
- Growing data is filtered, sorted, grouped, and paged in PostgreSQL, not loaded
  wholesale for in-memory processing.
- Treat indexes as candidates. Capture the exact predicate/join/order shape and
  verify representative PostgreSQL plans with `EXPLAIN (ANALYZE, BUFFERS)`;
  review overlap and write cost before adding one.
- Stream downloads/uploads or use presigned object-storage paths. Complete-file
  buffering requires a small enforced size limit and a test.

## Third-party communication

- Third-party clients live in `backend/external-services` and share configured,
  pooled transports with explicit connect, connection-acquisition, and response
  timeouts.
- Every Spring `RestClient` or `RestTemplate` used for third-party HTTP must
  register both the reusable `ExternalClientMetricsInterceptor` and
  `org.zalando.logbook.spring.LogbookClientHttpRequestInterceptor`. Generated
  integrations use `PooledRestClientFactory`; direct client builders at call
  sites are forbidden.
- SDK-managed transports use the reusable `ExternalCallTimer`; their timeout
  behavior and redaction require an explicit implementation and test before the
  integration is accepted.
- Emit per-logical-service request count, duration, error, and timeout metrics.

## Frontend request and loading rules

- One canonical TanStack query key owns each server resource. Reuse valid cache
  data instead of issuing equivalent requests under different keys.
- Queries wait for required identifiers/permissions and active ownership.
  Hidden tabs, closed dialogs, inaccessible branches, and unavailable inputs do
  not fetch by default.
- Pass TanStack Query's `AbortSignal` through the generated `openapi-fetch`
  boundary. Obsolete search/navigation requests must be cancellable and older
  responses must not replace newer state.
- Debounce search. Poll only for a real server lifecycle and stop on terminal
  state, unmount/hidden ownership, authorization loss, or error-policy limit.
- Apply authoritative mutation responses to the canonical cache or invalidate
  only affected keys. Do not refetch unrelated lists or invalidate after every
  item in a bulk operation.
- Lazy-load heavy editor, chart, admin, and other non-entry routes/features.
  Compare the existing Vite production-build asset output before and after.

## Logging, caching, and measurement

- Production/Replit Logbook output is metadata-only and body-free by default.
  Redact authorization/cookie/API-key headers. Never log JWTs, credentials,
  documents, uploads, arbitrary user content, or large generated payloads.
- A cache proposal must define location, complete security/tenant-aware key,
  cached value, reuse pattern, TTL, invalidation event, maximum size,
  consistency, stampede protection, and hit/miss/load metrics. Do not cache
  authorization-sensitive values across users/tenants.
- Expose Actuator/Micrometer metrics needed to validate changes: HTTP latency
  distributions, errors/timeouts, Hikari active/idle/pending/timeouts, JVM/GC,
  external-client duration/errors, cache hit/miss/eviction/load time, and
  payload size where practical. Preserve correlation/trace identifiers.
- Do not blanket-enable eager JPA associations, Hibernate query/L2 cache,
  endpoint caching, React memoization, list virtualization, JDBC batching,
  retries, larger pools, or speculative indexes.

## Multi-node operation

- Assume multiple application nodes even if the current local/Replit runtime is
  a single process. Correctness must not rely on in-memory state, node-local
  locks, sticky sessions, or one node observing another node's local cache.
- Node-local caches are optional performance hints. Define cross-node
  invalidation, bounded staleness, missed/duplicate-event behavior, and
  stampede protection. Reuse the database-backed invalidation mechanism when it
  is installed and sufficient.
- Scheduled jobs/startup routines are idempotent under concurrent nodes. When a
  job requires one owner, coordinate with an existing database-backed mechanism
  and verify lease/timeout/failure behavior; never assume only one scheduler.
- Redis is not in the baseline. Do not introduce it preemptively. Keep cache and
  coordination interfaces replaceable so Redis can be evaluated later against
  measured load, latency, consistency, availability, and operational cost.
- Attach the stateless `backend/observability` external-client metrics module
  to every node. Aggregate metrics across nodes; use only bounded-cardinality
  client/operation/outcome and instance/service tags.

## Pre-production contract policy

Generated applications are pre-production. If a chatty or overfetching API is
the root cause, change the OpenAPI contract and regenerate/update backend,
frontend, and tests together. Do not keep a legacy contract solely for backward
compatibility unless the user explicitly requests it. Security, authorization,
data correctness, transaction semantics, and intended behavior still apply.

## Completion checks

- Baseline and after-change evidence use the same workflow and data shape.
- Request/query counts are bounded and covered where the change affects them.
- External I/O is outside database transactions.
- Collections and payloads are bounded; summary and detail contracts are
  separated where their use differs.
- Pool/cache/index changes, if any, have measured justification and rollback.
- Backend tests, frontend tests/typecheck/lint/build, and supported verification
  gates pass.
