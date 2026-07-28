# Performance Engineering

Use these rules when changing request flows, queries, transactions, integrations,
frontend data fetching, caching, uploads, logging, or deployment behavior. They
are preventive defaults derived from observed cross-layer load amplification in
the reference application; they are not a substitute for measuring the current
project.

## Measurement first

- Establish the affected workflow before optimizing it:
  `user action -> React query/mutation -> endpoint -> controller -> service ->
  repository/external client -> mapping -> React update`.
- Record the smallest useful baseline: frontend request count, backend request
  latency, SQL count, response size, external-call duration, and bundle output
  as applicable.
- Use Actuator/Micrometer and existing tests/build output before adding new
  tools. Do not claim an improvement from a textual match alone.
- Add a focused regression assertion when a defect is load-amplifying: request
  count, query count, bounded result size, transaction boundary, or bundle
  chunk presence.

## Backend request and transaction boundaries

- Resolve authenticated user and permission context once per request/workflow
  and pass the resolved model through collaborators. Do not repeat identical
  user/permission lookups in one request.
- Do not save an authenticated-user row when synchronized identity fields did
  not change. Reads must not cause unconditional writes.
- Database transactions must contain database work only. Do not keep a
  transaction open across third-party HTTP/SDK calls, object storage, AI calls,
  file transfer, polling, sleeps, or other slow I/O. Split the workflow into
  short read/write transactions around the external call and preserve explicit
  state transitions and idempotency.
- Do not increase Hikari, servlet, scheduler, async, or HTTP-client pools until
  request concurrency, database capacity, downstream limits, queueing, and
  timeout ordering have been measured together.
- Upstream timeouts must exceed the bounded downstream operation plus local
  processing, or cancellation must stop downstream work. Retries are bounded,
  use backoff/jitter, and apply only to safe idempotent operations.

## API and persistence efficiency

- Collection endpoints are bounded by pagination, an explicit limit, or a
  demonstrably small invariant. Summary screens receive summary DTOs or
  projections; detail graphs are loaded only for detail workflows.
- Bulk user actions use one bulk contract and set-based service/repository work.
  Do not implement `N` selected items as `N` sequential browser requests or
  repository calls.
- Repository calls and lazy-association traversal inside loops are forbidden
  unless a query-count test proves the loop is bounded and intentional. Prefer
  set-based queries, `IN` batches, projections, entity graphs, or configured
  batch fetching selected for the workflow.
- Do not combine collection fetch joins with pageable queries without proving
  correct pagination and checking Cartesian-product/multiple-bag risk.
- Filter, sort, group, and page in the database when the source can grow. Do
  not load complete tables or membership/id sets merely to filter in memory.
- Indexes are candidates, not assumptions. Capture the exact query and verify
  representative plans (for PostgreSQL, `EXPLAIN (ANALYZE, BUFFERS)`) before
  adding an index; review write cost and overlap with existing indexes.
- Stream downloads and uploads or use a presigned object-storage path. Do not
  buffer complete files in JVM heap or browser memory without a small enforced
  size limit.

## Third-party HTTP

- Third-party HTTP clients live in `backend/external-services`, use bounded
  connection pools and explicit connect, connection-acquisition, and response
  timeouts, and expose latency/error metrics by logical service.
- Every Spring `RestClient`/`RestTemplate` used for third-party communication
  must register both the reusable `ExternalClientMetricsInterceptor` and
  `org.zalando.logbook.spring.LogbookClientHttpRequestInterceptor`; use the
  shared pooled client factory instead of constructing clients at call sites.
- SDK-managed calls use the reusable `ExternalCallTimer`; their outbound
  redaction and timeout behavior must be designed and tested before acceptance.

## Frontend request and loading behavior

- One canonical TanStack query key owns each server resource. Reuse valid
  cached data instead of issuing equivalent requests under different keys.
- Fetch only for active UI with resolved parameters. Hidden tabs, closed
  dialogs, inaccessible branches, and unavailable identifiers keep queries
  disabled.
- Pass TanStack Query's `AbortSignal` through the generated `openapi-fetch`
  boundary so obsolete searches/navigation requests can be cancelled and old
  responses cannot replace newer state.
- Debounce user-driven search; stop polling on terminal state, hidden/unmounted
  ownership, authorization loss, or error-policy exhaustion.
- Update authoritative mutation results in the canonical cache; otherwise
  invalidate only affected keys. A loop of mutations must not invalidate and
  refetch the same list after each item.
- Independent requests may run in parallel only after downstream/database
  capacity is considered. Do not parallelize database-heavy work merely to
  reduce wall-clock time.
- Use route/feature lazy loading for editor-, chart-, admin-, or other heavy
  surfaces that are not needed for the first usable screen. Compare Vite build
  output before and after; do not add a bundle analyzer dependency unless the
  repository already supports it or the user approves it.

## Logging, caching, and observability

- Production/Replit HTTP logs contain bounded metadata and redacted headers;
  request/response bodies are off by default. Never log JWTs, credentials,
  documents, uploads, large generated content, or arbitrary user data.
- Cache only a named expensive/repeated read with a defined key, tenant/user/
  permission isolation, TTL, maximum size, invalidation event, consistency
  model, stampede protection, and hit-rate/load-duration metrics. Do not cache
  authorization-sensitive responses across security boundaries.
- Do not blanket-enable Hibernate eager fetching, L2/query cache, endpoint
  caching, React memoization, list virtualization, JDBC batching, or larger
  pools. Require workflow evidence and a measurable acceptance criterion.
- Performance-relevant workflows should expose p50/p95/p99 HTTP latency, error
  and timeout rates, Hikari active/idle/pending/timeouts, external-client
  latency/errors, cache hits/misses/evictions, payload sizes, JVM/GC basics,
  and correlation/trace identifiers where the existing stack supports them.

## Multi-node operation

- Assume more than one application node even when local/Replit development runs
  one process. Correctness must not depend on in-memory maps, node-local locks,
  sticky sessions, or one node seeing another node's cache mutation.
- Node-local caches are performance hints only. Define cross-node invalidation
  (the existing database-backed cache event mechanism where installed), bounded
  staleness, and behavior after missed/duplicate events.
- Scheduled jobs and startup work must be idempotent and safe under concurrent
  nodes. Use database ownership/locking or another existing coordination
  mechanism when exactly-once ownership matters; do not assume one scheduler.
- Protect against cross-node cache stampedes with bounded concurrency, jittered
  expiry/refresh, or single-flight behavior appropriate to the current stack.
- Redis is not currently part of the baseline. Do not introduce it by default.
  Keep cache/coordination interfaces replaceable so Redis can be evaluated later
  from measured multi-node load, latency, consistency, and operational cost.
- Reusable external-client timing is stateless and attached to every node.
  Metrics may include a bounded instance identifier for diagnosis, while
  dashboards aggregate across nodes and avoid unbounded-cardinality tags.

## Pre-production contract changes

The generated applications are pre-production. When an inefficient contract is
the root cause, update OpenAPI, generated backend/frontend types, implementation,
and tests together. Do not preserve a legacy endpoint or DTO solely for backward
compatibility unless the user explicitly asks for it. Security, authorization,
data correctness, transaction semantics, and intended user behavior remain
non-negotiable.
