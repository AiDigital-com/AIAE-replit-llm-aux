# Canonical code patterns

Full code examples + extended "Why" rationale referenced from the main
`SKILL.md`. The SKILL keeps the rules; this file holds the worked
examples Agent copies and adapts.

## AppUser pattern (instead of pulling spring-security into service)

When a service method needs the caller's identity, controllers extract it
from the Spring Security context and pass an `AppUser` value object. The
service stays free of HTTP / JWT types. Do not add `@AuthenticationPrincipal`
to controller method signatures that implement generated OpenAPI interfaces:
the generated interface will not include that parameter.

```java
// application/.../<domain>/<Domain>Controller.java
@PostMapping("/{id}")
public ResponseEntity<<Domain>V1> update<Domain>(
        @PathVariable Long id,
        @RequestBody @Valid Update<Domain>RequestV1 req) {
    AppUser caller = AppUserFactory.from(
        SecurityContextHolder.getContext().getAuthentication());
    <Domain>Record record = service.update(id, mapper.toRecord(req), caller);
    return ResponseEntity.ok(mapper.toDto(record));
}
```

`AppUser` lives at `service/<base>/service/common/security/AppUser.java`
(alongside the `common/error/` and `common/observability/` subpackages)
as a plain Java `record` — no Spring imports. Application sees it
transitively (application depends on service); service classes that
receive it as a parameter import from the same module. The boundary
stays clean and service tests don't need `@WithMockUser`.

## Service that needs DB + external call

`external-services` is optional. Add it only when the project has a real
outbound integration and commit the first real client/adapter source files in
the same change. Once it exists, `service` is the only module that can talk to
both `domain` and `external-services`. External clients NEVER inject
repositories themselves — they return data; service writes via the repository.

```java
@Service
@RequiredArgsConstructor
public class <Domain>ServiceImpl implements <Domain>Service {
    private final <Domain>EntityService entityService; // transactional DB phases
    private final <External>Client externalClient;  // external-services module

    @Override
    public <Domain>Record syncFromExternal(Long id) {
        <Domain>ExternalReference reference = entityService.getExternalReference(id);
        <External>Data fresh = externalClient.fetch(reference.externalId());
        return entityService.applyExternalData(id, fresh);
    }
}
```

`getExternalReference` is a short read-only transaction and
`applyExternalData` is a short write transaction on a separate Spring bean.
The network call executes between them without retaining a database connection.

## Thin controller — canonical and anti-pattern

The four things a controller is allowed to do: receive call, extract user,
call ONE service method, MapStruct → DTO → return.

```java
// CANONICAL
@RestController
@RequiredArgsConstructor
class <Domain>Controller implements <Domain>Api {
    private final <Domain>Service service;
    private final <Domain>ApiMapper mapper;

    @Override
    public ResponseEntity<<Domain>V1> get<Domain>(Long id) {
        var caller = SecurityContextHolder.getContext().getAuthentication();
        <Domain>Record record = service.findById(id, AppUser.from(caller));
        return ResponseEntity.ok(mapper.toDto(record));
    }
}

// ANTI-PATTERN — DO NOT do any of this
@RestController
class <Domain>Controller implements <Domain>Api {
    public ResponseEntity<<Domain>V1> get<Domain>(Long id) {
        var entity = repo.findById(id).orElseThrow(...);   // ✗ repository in controller
        if (entity.getOwnerId() != currentUser.getId() &&  // ✗ business logic
            !currentUser.isAdmin()) {
            throw new ResponseStatusException(FORBIDDEN);  // ✗ wrong exception type
        }
        var dto = new <Domain>V1();                        // ✗ manual DTO build
        dto.setId(entity.getId());
        dto.setName(entity.getName());
        return ResponseEntity.ok(dto);
    }
}
```

The service does the business work (department check, status validation,
etc.) and throws `AppException` on any failure. The mapper does the shape
translation only.

## Service interface + impl — full canonical shape

Service interfaces are the business contract. They must be documented even when
the implementation is obvious: callers should understand parameters, returned
state, authorization assumptions, and business failures without opening the
implementation. Implementations stay focused on orchestration and delegate
validation, algorithmic work, assembling, prompt construction, scoring, and
provider translation to focused collaborators.

Service interfaces must not expose `Map<String, Object>`, `Object`, or
`List<Map<String, Object>>` as request/result contracts. When the source system
is dynamic (OpenAI JSON, provider metadata, JSONB, webhook payloads), put the
known business shape into typed records and isolate raw maps in a named boundary
converter or provider adapter. A method named `generateRevisionBrief` returns a
`RevisionBriefGenerationResultRecord`, not a map containing `brief` and
`metadata` keys.

Hard limits enforced by `scripts/lib/check-service-contract-quality.sh`:
`*ServiceImpl` max 260 lines, 10 public methods, 8 private methods, 8 injected
fields, 60 lines per public method, and 35 lines per private method. If the
class approaches those limits, split before continuing.


```
backend/service/src/main/java/<base>/service/<domain>/
  services/<X>Service.java            ← public interface, what callers inject
  services/impl/<X>ServiceImpl.java   ← @Service implementation
  mappers/<X>Mapper.java              ← MapStruct Entity ↔ Record
  models/<X>Record.java
  models/<X>Update.java
```

```java
// services/<X>Service.java — interface, no Spring annotations
/**
 * Coordinates business operations for <x> records.
 */
public interface <X>Service {

    /**
     * Finds a <x> by its persistent identifier.
     *
     * @param id persistent <x> identifier
     * @return matching <x> record
     */
    <X>Record findById(Long id);

    /**
     * Applies writable changes to a <x> visible to the caller.
     *
     * @param id persistent <x> identifier
     * @param update writable fields to apply
     * @param caller authenticated business caller
     * @return updated <x> record
     */
    <X>Record update(Long id, <X>Update update, AppUser caller);

    /**
     * Searches <x> records with filtering and pagination.
     *
     * @param query search filters
     * @param pageable requested page and sort
     * @return page of matching <x> records
     */
    Page<<X>Record> search(<X>Query query, Pageable pageable);
}

// services/impl/<X>ServiceImpl.java — ONLY this carries @Service
@Service
@RequiredArgsConstructor
public class <X>ServiceImpl implements <X>Service {

    private final <X>Repository repo;
    private final <X>Mapper mapper;

    @Override
    public <X>Record findById(Long id) {
        return repo.findById(id)
            .map(mapper::toRecord)
            .orElseThrow(() -> new AppException(ErrorReason.C001, id));
    }
    // ...
}
```

### Why interface + impl rather than just the impl class

1. **Testability** — controllers in unit tests mock `<X>Service`, not
   `<X>ServiceImpl`. Mockito handles both, but the typed boundary makes
   intent obvious.
2. **Refactor safety** — adding a second implementation (a `Mock<X>Service`
   for a feature flag, a `Caching<X>ServiceImpl` decorator) doesn't
   require ripping out all the `<X>ServiceImpl` references at call sites.
3. **Self-invocation + AOP** — Spring AOP proxies must be applied at the
   interface seam. If a caller injects the impl class directly, certain
   proxy modes degrade. Interfaces sidestep the issue.

## MapStruct composition via `uses`

When a mapper needs to convert nested types that another mapper already
handles, wire them through `@Mapper(config = ..., uses = ...)` — never
duplicate the conversion code.

```java
// service/.../mappers/order/OrderItemMapper.java
@Mapper(config = ServiceMapperConfig.class)
public interface OrderItemMapper {
    OrderItemRecord toRecord(OrderItemEntity entity);
    OrderItemEntity toEntity(OrderItemRecord record);
}

// service/.../mappers/order/OrderMapper.java
@Mapper(config = ServiceMapperConfig.class, uses = OrderItemMapper.class)
public interface OrderMapper {
    // OrderItemMapper handles List<OrderItem> ↔ List<OrderItemRecord>
    // and Optional<OrderItem> ↔ Optional<OrderItemRecord> automatically.
    // No per-field @Mapping(qualifiedByName=...) needed.
    OrderRecord toRecord(OrderEntity entity);
    OrderEntity toEntity(OrderRecord record);
}
```

Composition through `uses` keeps each mapper small, makes each one
unit-testable in isolation, and lets MapStruct inject the dependency via
Spring (through the shared mapper config) so mappers don't need to manually
instantiate each other.

## Create/update mapping plus `CurrentTime`

Services orchestrate; MapStruct copies service model fields; `CurrentTime` supplies
technical timestamps.

```java
// FORBIDDEN
CaseStudyEntity entity = new CaseStudyEntity();
entity.setTitle(model.title());
entity.setClientName(model.clientName());
entity.setStatus("SUBMITTED");
entity.setCreatedAt(LocalDateTime.now(ZoneOffset.UTC));

// REQUIRED
CaseStudyEntity entity = caseStudyMapper.toEntity(model);
entity.setStatus(CaseStudyStatus.SUBMITTED);
entity.setCreatedAt(currentTime.nowLocalDateTime());
return caseStudyMapper.toRecord(caseStudyRepository.save(entity));
```

For updates, put writable field copying in a mapper method:

```java
@Mapper(config = ServiceMapperConfig.class)
public interface CaseStudyMapper {
    CaseStudyEntity toEntity(CreateCaseStudyModel model);

    @BeanMapping(nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    void updateEntity(UpdateCaseStudyModel model, @MappingTarget CaseStudyEntity entity);
}
```

`CreateCaseStudyModel` and `UpdateCaseStudyModel` live under the aggregate's
`service/.../models/` package. Do not introduce `*Command` types for service
inputs.

## Two MapStruct mappers per resource

Never create a single `ApiDtoMapper`, `DtoMapper`, `ApplicationMapper`,
`CommonMapper`, or `application/.../mappers/<aggregate>/*` mapper package root. That is a
god object and hides aggregate ownership. API mappers live under `application/.../mappers/<aggregate>/` and are MapStruct interfaces, not hand-written `@Component` classes.
Composition is explicit with `uses = ...`.

Do not implement API mapper methods as `default` methods that accept `Map<String, Object>`, call `new SomeV1()`, or use generic coercion helpers. That is hand-written mapping wearing a MapStruct annotation. Fix the service contract to return typed records, then let MapStruct generate the mapping.

Do not create artificial list wrappers such as `LessonsListSource`,
`UsersListSource`, `RoadmapsListSource`, or one-field service records like
`LessonsListRecord(List<LessonSummaryRecord> lessons)` just to let MapStruct map
a `List<T>` into a response DTO. Those records are mapper plumbing, not business
contracts. For simple list use cases, the service returns `List<T>` and the API
mapper maps that parameter into the generated response wrapper.

Forbidden:

```java
public record LessonsListSource(List<LessonSummaryRecord> lessons) { }
public record LessonsListRecord(List<LessonSummaryRecord> lessons) { }

@Mapper(config = ApplicationMapperConfig.class)
public interface LessonApiMapper {
    LessonsListResponseV1 toDto(LessonsListRecord record);
}
```

Correct:

```java
public interface LessonService {
    List<LessonSummaryRecord> getAllLessons(AppUser viewer);
}

@Mapper(config = ApplicationMapperConfig.class)
public interface LessonApiMapper {
    @Mapping(target = "lessons", source = "lessons")
    LessonsListResponseV1 toDto(List<LessonSummaryRecord> lessons);
}
```

Only create a list result record when it has real additional business fields,
such as `items + total + page + pageSize`.

Forbidden:

```java
@Component
public class ApiDtoMapper {
    LessonV1 toLesson(LessonRecord record) { ... }
    MaterialV1 toMaterial(MaterialRecord record) { ... }
}
```

Correct:

```java
@Mapper(config = ApplicationMapperConfig.class, uses = LessonActivityApiMapper.class)
public interface LessonApiMapper {
    LessonV1 toDto(LessonRecord record);
}
```

```java
@Mapper(config = ApplicationMapperConfig.class, uses = CommonEnumApiMapper.class)
public interface PermissionApiMapper {
    UserPermissionSnapshotV1 toUserPermissionSnapshotV1(PermissionSnapshotRecord record);
}

@Mapper(config = ApplicationMapperConfig.class)
public interface CommonEnumApiMapper {
    UserRoleCodeV1 toUserRoleCodeV1(String roleCode);
    default String toRoleCode(UserRoleCodeV1 roleCode) {
        return roleCode == null ? null : roleCode.getValue();
    }
}
```

Named OpenAPI enum schemas are reusable Java enum classes. Do not reference
nested generated enum names such as `UserPermissionSnapshotV1.RoleCodeEnum` in
application code. If a service record stores a code as `String` or a domain enum,
create a small dedicated enum mapper under `application/.../mappers/common/` or
the owning aggregate mapper folder and add it via MapStruct `uses = ...`.


| Direction | Location | Purpose |
|---|---|---|
| `Entity ↔ ServiceRecord` | `service/` module | Hide JPA, return immutable records to controllers/other services |
| `ServiceRecord ↔ ApiDto` (generated by openapi-generator) | `application/` module | Convert between business records and wire format |

```java
// service/.../mappers/<domain>/<Domain>Mapper.java
@Mapper(config = ServiceMapperConfig.class)
public interface <Domain>Mapper {
    <Domain>Record toRecord(<Domain>Entity entity);
    <Domain>Entity toEntity(<Domain>Record record);
    List<<Domain>Record> toRecords(List<<Domain>Entity> entities);
}

// application/.../mappers/<domain>/<Domain>ApiMapper.java
@Mapper(config = ApplicationMapperConfig.class)
public interface <Domain>ApiMapper {
    <Domain>V1 toDto(<Domain>Record record);                  // V1 DTO from openapi-generator
    <Domain>Record toRecord(Create<Domain>RequestV1 req);     // V1 request from openapi-generator
}
```

Entities never escape the `domain` module — they're not arguments or
return types of any controller, mapper-to-DTO, or external-service call.

## Test method naming + Gherkin body (house style)

Every `@Test` method, JUnit or Vitest, follows this convention:

- **Name:** `shouldDoSomethingTest()` — starts with `should`, describes the
  expected behaviour in camelCase, ends with the literal `Test` suffix.
  Forbidden: `getMeRequiresAuthentication`, `findById_returnsRecord_whenExists`,
  `testFindById`. Required: `shouldRejectUnauthenticatedRequestTest`,
  `shouldThrowAppExceptionWhenEntityMissingTest`.
- **Body:** three Gherkin section markers — `// Given:`, `// When:`,
  `// Then:` — pure separators for arrange / act / assert. **Bare markers
  only — no descriptive text after the colon.** The code below each marker
  IS the description; the comment must not duplicate it. One blank line
  between sections.
- **Vitest:** the `should` opener moves into the `it(...)` string;
  `// Given:` / `// When:` / `// Then:` still structure the body.
- **Empty tests get NO markers.** When the assertion is "the harness loaded
  without throwing" (`@SpringBootTest` smoke, `@DataJpaTest` changelog
  smoke), an empty body is the right form. Don't wrap nothing in
  Given/When/Then.

```java
@Test
void shouldReturnUserPayloadFromJwtClaimsTest() throws Exception {
    // Given: a valid Clerk JWT — the jwt() test post-processor injects it
    // directly (no live IdP, no decoder call).

    // When:
    var response = mvc.perform(get("/api/v1/auth/me")
        .with(jwt().jwt(j -> j.subject("user_123").claim("email", "alice@example.com"))));

    // Then:
    response.andExpect(status().isOk())
            .andExpect(jsonPath("$.email").value("alice@example.com"));
}
```

```ts
it("should render the scaffold heading test", () => {
    // Given:
    const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });

    // When:
    render(<QueryClientProvider client={qc}><App /></QueryClientProvider>);

    // Then:
    expect(screen.getByRole("heading", { level: 1 })).toBeTruthy();
});
```

**Review check (grep-able):**
```bash
# Find Java test methods NOT matching shouldDoSomethingTest convention.
# Expected: zero output.
grep -rEn 'void [a-z][a-zA-Z0-9_]+\(\)' backend/**/src/test/java/ \
  | grep -vE 'void should[A-Z][a-zA-Z0-9]*Test\('
```
