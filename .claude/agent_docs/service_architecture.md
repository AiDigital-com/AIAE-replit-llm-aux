# Service Architecture

## Backend services

These rules apply to services under `backend/service`.

## Core boundary rule

Use this rule everywhere:

```text
1 entity = 1 repository = 1 service to work with that entity
```

For example, `UserRepository` is used through `UserService`, and
`RoleAssignmentRepository` is used through `RoleAssignmentService`. Apply the
same ownership rule to every persisted entity using the project's actual names.

## What orchestrators may do

Cross-entity query, administration, current-user, and integration orchestration
services may coordinate:

- entity services
- validators
- mappers
- external-service clients
- exception factories / error enums

They must not inject repositories directly.

## Why this rule exists

- Repository ownership stays obvious.
- Locking and query semantics stay centralized per entity.
- Authorization or other orchestration services stay at the business layer instead of becoming ad-hoc data-access hubs.
- Unit tests stay cleaner because cross-entity behavior mocks service contracts, not repositories.

## Example

A permission query service reads user data through `UserService` and assignment
data through `RoleAssignmentService`. It must not inject `UserRepository` or
`RoleAssignmentRepository` directly.

## Additional backend service rules

- Transactions belong in the service layer.
- Outbound HTTP/SDK calls belong in `backend/external-services`, never in entity services or controllers.
- A transaction must not span an outbound HTTP/SDK call, object-storage
  operation, AI call, file transfer, poll/sleep, or other slow I/O. Split the
  orchestration into short database phases around the external call and make
  intermediate state/idempotency explicit.
- Third-party Spring HTTP clients use the shared pooled factory with both
  `ExternalClientMetricsInterceptor` and `LogbookClientHttpRequestInterceptor`,
  plus explicit timeouts. SDK-managed calls use the reusable
  `ExternalCallTimer`.
- Production beans expose no `private` methods. Extract validators, policies, assemblers, or helpers (each unit-testable) instead of hiding logic in private methods, and keep collaborator methods package-private so they are spyable. Only `private static final` constants and `private final` fields stay private.
- Data carried between collaborators (resolved rows, command results, view models) is a top-level type in the `model` package, never a nested record/class.
- MapStruct mappers stay narrow: entity-to-model in `service`, model-to-contract in `application`.
