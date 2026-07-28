# Backend Test Style Rules

Single source of truth for backend test style in generated Java backends.
Use together with `testing-policy.md`: that file defines minimum coverage and phase gates;
this file defines the shape of the tests themselves.

Production-code prerequisites these tests assume (see `testing-policy.md` and
`structure/service-helper-extraction-policy.md`): no `static` or `private`
methods on beans/services (helpers are package-private so they are spyable), no
nested data types (records/DTOs are top-level in `model`/`enums`), and JavaDoc on
every handwritten production method.

## Mandatory style

- Keep JUnit 5 test classes, test methods, and lifecycle methods
  package-private unless inheritance across packages or the Java module path
  requires `public`; they must never be `private`.
- Declare every test class field `private`. This includes Mockito
  `@Mock`, `@Spy`, `@Captor`, and `@InjectMocks` fields, Spring-injected test
  fields, containers, and shared fixtures. Add `static` and/or `final` where
  appropriate, but never rely on implicit package-private field visibility.
- Test method names use `should...Test()`.
- Structure each test with `// Given:`, `// When:`, and `// Then:`.
- `// When-Then:` is acceptable for direct exception assertions.
- Create the system under test and all fixtures directly inside each test method.
- Do not add common fixture factories, shared setup helpers, or reusable builder methods for unit tests.
- Use Instancio for entities, models, and DTOs instead of hand-building object graphs.
- Pin the fields the assertion reads with `set(field(...))` and leave everything else
  to the generator:

  ```java
  Epicrisis epicrisis = Instancio.of(Epicrisis.class)
      .set(field(Epicrisis::getStatus), SimiDocumentStatusEnum.DRAFT.name())
      .create();
  ```

  Instancio exists to stop hand-building fields the test does not care about. A field
  the assertion depends on is one the test *does* care about, so leaving it random
  makes the test either vacuous or intermittently red.
- `any()` / `anyList()` are forbidden for normal verification; use `ArgumentCaptor`, `eq`, `same`, or explicit values.
- When a public service method delegates to another package-private method of the same class and the test needs isolation, instantiate the service as `spy(new ...ServiceImpl(...))` and stub the inner call with `doReturn` / `doThrow`. (Production keeps such methods package-private, never `private`, so they stay spyable.)

## Service-layer unit tests

- Service tests are pure Mockito unit tests.
- Mock collaborators at the service boundary.
- Never bypass the architecture by mocking or calling another entity's repository directly from a higher-level service test.
- If the code under test orchestrates multiple entities, mock the paired entity services instead of their repositories.

## MVC tests

- Every controller gets its own unit test. Loading the Spring context is not a
  substitute: a context test proves the beans wire together, not that the endpoint
  maps its request, returns the documented status, or forwards the right arguments to
  the service. An `@SpringBootTest` that merely starts and stops leaves the controller
  untested.
- Mock the controller's collaborators — `@WebMvcTest(controllers = XController.class)`
  with mocked beans, or a standalone MockMvc setup. Do not reach the database.
- Prefer standalone MockMvc tests.
- Assert request path, status, payload, and collaboration arguments.
- Register controller advice explicitly when error mapping is part of the contract under test.

## Repository tests

- Write `@DataJpaTest` only for non-trivial or business-critical queries.
- Seed focused SQL scenarios with `@Sql`.
- Do not spend repository tests on trivial derived queries unless the query is genuinely risky.
