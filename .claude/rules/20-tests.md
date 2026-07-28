---
description: Backend test style rules.
paths:
  - "backend/*/src/test/**/*.java"
---

# Backend Test Rules

- Use JUnit 5.
- Keep JUnit 5 test classes, test methods, and lifecycle methods
  package-private unless cross-package inheritance or the Java module path
  requires `public`; never make them `private`.
- Declare every test class field `private`, including Mockito annotations,
  Spring-injected fields, containers, and shared fixtures. Add `static` or
  `final` where appropriate; implicit package-private fields are forbidden.
- Use `should...Test()` naming.
- Structure tests with `// Given:`, `// When:`, and `// Then:`.
- `// When-Then:` is acceptable for direct exception assertions.
- Create fixtures inside each test method. Do not add common fixture methods or shared mutable setup.
- Use Instancio for entities, models, and DTOs instead of manual object creation whenever practical.
- Set every field an assertion depends on explicitly; let Instancio generate the rest:
  `Instancio.of(X.class).set(field(X::getStatus), StatusEnum.DRAFT.name()).create()`.
  A fully random object makes the assertion either vacuous or flaky — the point of
  Instancio is to stop hand-building irrelevant fields, not to randomise relevant ones.
- `any()` / `anyList()` are forbidden for normal verification. Use `ArgumentCaptor`, `eq`, `same`, or explicit values.
- When a public service method delegates to another non-private method of the same class and the test needs isolation, mock that inner call via `spy(...)` and `doReturn` / `doThrow`. Production code keeps such methods package-private (never `private`) precisely so they stay spyable.
- Service-layer tests are pure Mockito unit tests.
- Controllers need their own unit tests. A test that only loads the Spring context
  does not count as testing a controller: it proves the beans wire up, not that the
  endpoint maps the request, returns the right status, or passes the right arguments
  on. Use `@WebMvcTest` for the single controller with its collaborators mocked, or a
  standalone MockMvc setup, and assert path, status, payload, and the arguments the
  controller forwards.
- Repository tests with `@Sql` are worth writing only for custom or heavy queries, not for trivial derived methods.

## Coverage phases

Coverage is phased so that tests never block feature discovery, but are never
skipped either. The phase is a committed decision in `.template-phase`:

| Phase | Line | Branch | When |
|---|---|---|---|
| `mvp` | 0.30 | 0.25 | while the product is being built |
| `engineering` (default) | 0.80 | 0.70 | from finalization onward |

- The strict values are the **pom defaults**, so a bare `mvn verify` is always
  strict. The relaxed floor requires `-Pmvp`, which the verify scripts pass only
  while `.template-phase` reads `mvp`.
- The floor is non-zero in every phase. A 0.00 gate lets coverage start at
  nothing and turns finalization into one large batch of test-writing.
- Finalizing coverage is a **required, non-skippable last step**:
  `prepare-engineering-handoff.sh` refuses to run while the phase is `mvp`. Use
  the `finalize-coverage` skill.
- Never close a coverage gap by lowering a threshold, adding a jacoco
  `<exclude>` for hand-written code, or passing `-Djacoco.skip`. All three are
  rejected by `scripts/lib/check-coverage-integrity.sh`.
- Never close a gap with an assertion-free test. Executing a line without
  asserting behavior raises the metric while lowering the value of the suite —
  the same cheat as lowering the gate, one layer up.
- If a class cannot reasonably be tested, extract its logic into a collaborator
  and test that. Production methods are package-private rather than `private`
  precisely so this is always possible.
