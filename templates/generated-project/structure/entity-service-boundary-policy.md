# Entity-Service Boundary Policy

Single source of truth for entity access boundaries in generated Java backends.

## Core rule

Use this rule everywhere:

```text
1 entity = 1 repository = 1 service to work with that entity
```

For every persisted entity:
- create exactly one repository in `domain`
- create exactly one paired entity service contract in `service/entity`
- keep direct repository access inside that paired entity service implementation

## What this means in practice

- Controllers never inject repositories.
- Cross-entity orchestration services never inject repositories directly.
- Query services, authorization services, administration services, and workflow services depend on entity services, not repositories.
- If a query primarily loads or locks one entity, place it in that entity repository and expose it through that entity service.

## Why this rule exists

- Repository ownership stays explicit.
- Locking and query semantics stay centralized per entity.
- Orchestration services remain business-layer code instead of becoming ad-hoc data-access hubs.
- Unit tests stay cleaner because higher-level services mock entity-service contracts instead of repository internals.

## Allowed collaboration pattern

```text
controller -> orchestration service -> entity service -> repository
```

And when integrations are involved:

```text
controller -> orchestration service -> entity service / external-services client
```

## Forbidden patterns

- `RbacQueryServiceImpl`-style service injecting multiple repositories directly.
- Repository access from `application` classes.
- Repository access from validators, mappers, or external-service clients.
- Creating a second service for the same entity just because one use case needs a different query.
