# Multi-Node Cache Management Rules

The canonical runtime and handoff-safe contract is:

```text
.claude/agent_docs/distributed_cache.md
```

Read and preserve that file when materializing a project. Do not maintain a
second implementation guide under `templates/`; `templates/` is removed during
engineering handoff.

The scaffold supplies the complete mechanism as one removable unit:

- active `backend/cache-management` runtime dependency;
- shared Hibernate/Spring JCache manager;
- PostgreSQL `cache_invalidation_event` outbox and Liquibase migration;
- JPA event service with transaction-mandatory publication;
- monotonic event-ID polling in bounded pages;
- empty application-owned registry extension point;
- scheduling, retention, registry verification, and tests.

Project generation must populate the registry and add publication calls only
for caching decisions justified by the actual application. Never blanket-cache
entities or queries.

## Initialization decision

Caching is optional, but partial cache infrastructure is forbidden.

- If the application has a concrete, measured L2/query/Spring-cache candidate,
  keep the complete stack and follow `distributed_cache.md`.
- If it has no cache candidate, run
  `bash scripts/remove-cache-management.sh --apply` during initialization.
  The command removes Ehcache/JCache, Hibernate L2 configuration, the
  `cache-management` module, the outbox service/entity, and its migration
  together.
- If application code already contains cache annotations or invalidation calls,
  the removal command fails closed instead of deleting them.

Do not toggle individual dependencies or configuration blocks by hand. CI
accepts exactly two coherent states: complete cache + invalidation, or neither.
