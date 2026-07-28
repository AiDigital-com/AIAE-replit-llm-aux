---
description: Cross-layer performance and load-amplification rules.
paths:
  - "backend/**/*"
  - "frontend/**/*"
  - ".github/workflows/**/*"
  - "docker-compose.yml"
  - ".replit"
  - "replit.nix"
---

# Performance Rules

- Measure the affected workflow before tuning it. Record applicable request
  count, SQL count, latency, payload size, external-call duration, and bundle
  output, then add a focused regression assertion.
- Resolve authenticated user/permission context once per request and never
  issue an unchanged user `save` from a read path.
- Do not hold a database transaction across third-party HTTP/SDK calls, object
  storage, AI work, file transfer, polling, sleeps, or other slow I/O.
- Collection/list endpoints are bounded and return summary DTOs/projections.
  Load detail graphs only for detail workflows.
- Repository calls and lazy-association traversal inside loops are forbidden.
  Use set-based/batched queries and verify query counts; review fetch-join
  pagination and Cartesian-product risk.
- Bulk UI actions use one bulk endpoint and set-based persistence, not
  sequential per-item HTTP and database calls.
- Filter, sort, group, and page growing data in the database. Add indexes only
  after verifying the exact query plan and reviewing write cost.
- Stream or presign file transfers; do not heap-buffer complete files without a
  small enforced limit.
- Every third-party Spring HTTP client registers both
  `ExternalClientMetricsInterceptor` and `LogbookClientHttpRequestInterceptor`
  through the shared pooled client factory, with bounded pools and explicit
  timeouts. SDK-managed calls use `ExternalCallTimer`.
- Production/Replit HTTP logging is redacted, metadata-only, and body-free by
  default.
- TanStack queries use one canonical key owner, run only for active/resolved UI,
  pass `AbortSignal` through `openapi-fetch`, debounce search, stop bounded
  polling, and invalidate only affected keys.
- Lazy-load heavy routes/features not needed for the first usable screen and
  compare supported Vite build output before/after.
- Do not increase pools or blanket-add caching, eager fetching, memoization,
  virtualization, retries, or indexes without measured evidence and a bounded
  acceptance criterion.
- Assume multiple nodes: no node-local correctness state/locks, cross-node cache
  invalidation with bounded staleness, idempotent/coordinated scheduled jobs, and
  stampede protection. Redis is absent; keep boundaries replaceable but do not
  add Redis without measured need and explicit approval.
- Cache invalidation uses the shared DB outbox and monotonic event-ID protocol
  in `.claude/agent_docs/distributed_cache.md`; timestamp polling is forbidden.
- Pre-production API contracts may be changed directly when OpenAPI, generated
  types, backend, frontend, and tests move together; do not retain an inefficient
  legacy variant unless explicitly requested.
