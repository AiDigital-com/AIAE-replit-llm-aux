# L2 Cache and Cross-Node Invalidation

Read this document before adding Hibernate L2 caching, query caching, Spring
`@Cacheable`, cache warm-up, or mutations of already cached data.

## Installation state

This stack is optional. A project with a concrete cache candidate keeps the
entire mechanism described below. A project with no cache candidate runs
`bash scripts/remove-cache-management.sh --apply` and contains neither L2
caching nor cross-node invalidation. Partial states are invalid.

## Installed baseline

- Hibernate L2 and query-cache infrastructure uses Ehcache through JCache.
- Spring and Hibernate use the exact same `javax.cache.CacheManager` instance
  created by application `CacheConfig`.
- Cache regions are node-local performance hints. Correctness must not depend
  on one node observing another node's in-memory eviction.
- The `cache-management` module propagates invalidation through the shared
  PostgreSQL `cache_invalidation_event` outbox.
- Redis is not part of the baseline. Introduce it only from measured need and
  an explicit consistency, availability, and operations decision.

Do not enable caching simply because the infrastructure exists. Require a named
repeated/expensive read, a measurement target, and a memory/consistency budget.

## When L2 is appropriate

Prefer L2 for read-mostly reference/dictionary entities with stable IDs and
bounded cardinality. For every cached entity or query define:

- exact cache key and tenant/user/permission isolation;
- explicit region name;
- concurrency strategy appropriate to its mutation rate;
- TTL and maximum entries or bytes in `ehcache.xml`;
- invalidation sources and bounded-staleness expectation;
- hit/miss/eviction and load-duration evidence.

Do not cache authorization-sensitive results across security boundaries. Do not
blanket-enable caching on every entity/query. Do not create
`ConcurrentMapCacheManager`, static maps, or a second JCache manager.

Every Hibernate cached entity must declare an explicit region. Every cacheable
query must declare both the cacheable hint and a named query region. The
region-prefix-adjusted alias must exist in `ehcache.xml`; implicit regions fail.

## Mutation and outbox contract

For each mutable source feeding a cache region:

1. Add the source class and every affected L2/query/Spring region to
   `ApplicationCacheNamesByClassRegistry`.
2. Keep the mutation inside a narrow service transaction.
3. Call `CacheInvalidationEventService.publishUpdateEvent(Source.class)` in
   that same transaction after the successful repository mutation.
4. Keep targeted local `@CacheEvict` when same-request/same-node immediacy is
   required. The outbox event reaches every node.

Publication uses `Propagation.MANDATORY`: calling it outside the mutation
transaction fails. The domain mutation and invalidation row therefore commit or
roll back atomically.

## Polling protocol

- Event identity and ordering use the database-generated monotonic `id`, never
  application clocks or timestamps.
- Consumers query `id > lastProcessedId ORDER BY id` in bounded pages.
- Advance the node-local cursor only after the corresponding regions clear.
- Clearing is idempotent. Duplicate delivery and replay are safe.
- A failed clear leaves the cursor unchanged and is retried.
- Outbox pruning is disabled by default. A restarted node begins with empty
  heap-local caches and may safely replay from sequence zero, but a still-live
  node can retain stale entries if an unprocessed event is pruned.
- Enable time-based retention only with an enforced maximum polling outage,
  polling-lag alerts, and a restart or full-cache-clear policy for nodes that
  exceed that bound.
- Keep polling batches bounded. Alert on persistent backlog, polling failures,
  unknown tracked classes, or missing regions.

Do not replace this with `updatedAt > lastPollTime`: an event timestamped before
a poll but committed after its query can be skipped permanently.

## Warm-up

Warm-up is disabled by default. If measurements justify it, load a small,
explicit set of read-mostly dictionaries sequentially or with explicitly
bounded concurrency. Account for simultaneous node restarts; never use an
unbounded `parallelStream()` startup warm-up.

## Required verification when installed

- The application runtime depends on `cache-management` and enables scheduling.
- Registry verification resolves every configured region in non-production/CI.
- Mutation commit creates one event; rollback creates none.
- Publication outside a transaction fails.
- Polling processes increasing IDs and retries a failed eviction.
- Spring and Hibernate receive the same JCache manager instance.
- A real L2 integration test proves remote invalidation causes the next read to
  hit the database for each production cached entity/query family.
