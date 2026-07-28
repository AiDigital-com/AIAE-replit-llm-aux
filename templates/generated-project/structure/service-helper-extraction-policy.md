# Service helper extraction policy

Keep `*ServiceImpl` focused on business orchestration. Extract a `*ServiceHelper`
interface and `*ServiceHelperImpl` when logic is:

- independently testable
- reused across service methods
- algorithmic or non-trivial
- obscuring the orchestration flow

Do **not** create helpers for one-line formatting or trivial mapping.

## Canonical layout

```
service/<feature>/services/<Feature>Service.java
service/<feature>/services/impl/<Feature>ServiceImpl.java
service/<feature>/helpers/<Feature>ServiceHelper.java
service/<feature>/helpers/impl/<Feature>ServiceHelperImpl.java
```

## Rules

- `ServiceImpl` depends on the helper **interface**, never the implementation.
- Helpers must not call external HTTP APIs directly.
- Helpers receive external-services client interfaces when outbound calls are required.
- Meaningful helper logic requires unit tests.
- No `HelperUtils`, static god-classes, or empty helpers.
- No `private` methods on beans/services. Helper methods that stay inside a
  service are **package-private** so unit tests can spy/stub them; only
  `private static final` constants and `private final` fields stay private.
  When extraction adds no value, keep the method package-private rather than
  private — never `private`.

## Hard service size limits

`*ServiceImpl` is an orchestration class, not a dumping ground for all business
logic. When a service starts accumulating parsing, grading, aggregation, provider
translation, prompt building, scoring, fan-out, or lifecycle state-machine logic,
extract that logic into focused collaborators before the implementation becomes
large.

Generated production code must satisfy these limits:

- `*ServiceImpl` max 260 physical lines.
- `*ServiceImpl` max 10 public methods.
- `*ServiceImpl` max 8 package-private helper methods (no `private` methods at all).
- `*ServiceImpl` max 8 injected fields.
- Public service method body max 60 lines.
- Package-private helper method body max 35 lines.

If any limit is hit, split by responsibility instead of adding another private
method. Preferred collaborators: `<Feature>Validator`, `<Feature>Policy`,
`<Feature>Assembler`, `<Feature>Workflow`, `<Feature>PreparationService`,
`<Feature>Generator`, `<Feature>ScoringService`, or a narrow
`<Feature>ServiceHelper` interface when the helper is reused and independently
testable.

Forbidden patterns:

- A `*ServiceImpl` with a large pile of helper methods acting as a second class
  hidden inside the service.
- Any `private` method on a bean/service (use package-private so it is spyable).
- A nested record/DTO/data class declared inside a service or other class —
  extract it to a top-level type in `model`/`enums`.
- Several unrelated workflows in one service because they share the same table.
- Algorithmic logic kept inside the service only to avoid creating another bean.
- `HelperUtils` / static utility classes.

The gate is `scripts/lib/check-service-contract-quality.sh`; `verify-gates.sh`
runs it automatically.
