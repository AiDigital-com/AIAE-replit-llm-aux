# Canonical OpenAPI Rules

Single source of truth for OpenAPI. Other files reference this; never duplicate.

## Spec file

- Path: `src/main/resources/api/v1/specs/openapi.yaml`
  (e.g. `backend/application/src/main/resources/api/v1/specs/openapi.yaml`).
- **OUTSIDE `src/main/resources/static/`** — Vite's `outDir` is `static/` with
  `emptyOutDir: true`, so `npm run build` wipes everything there. Past sessions
  burned hours on "OpenAPI generator NPE: inputSpec is null" because spec got
  deleted between builds.
- `OpenApiSpecConfig` (WebMvcConfigurer) restores the public URL
  `/api/v1/specs/openapi.yaml` by mapping to `classpath:/api/v1/specs/`.
  SpringDoc + frontend `openapi-typescript` read from that URL.
- Committed as static file. OpenAPI is source of truth; controller annotations are not.

## Required top-level keys

`openapi: 3.0.3`, `info.title`, `info.version`, `servers`, `tags`, `paths`,
`components.securitySchemes`, `components.schemas`.

Tag-driven grouping (code generation uses tags).

### `/api/v1` prefix — must live in path keys, NOT only in `servers`

`servers: [{ url: /api/v1 }]` is **documentation only**. The `spring`
generator of `openapi-generator-maven-plugin` IGNORES `servers[].url` when
emitting Spring route mappings — controllers carry the path keys verbatim.
If your spec has `paths: { /employees: ... }`, Spring registers
`@GetMapping("/employees")`, NOT `@GetMapping("/api/v1/employees")`. The
Vite proxy, `AuthConstants.PUBLIC_PATHS`, SpringDoc URLs, and
manually-curl'd endpoints all expect `/api/v1/...` — generated routes that
omit the prefix produce 404s everywhere downstream.

**Correct (every path key carries the full prefix):**

```yaml
servers:
  - url: /api/v1               # documentation hint for Swagger UI
paths:
  /api/v1/employees:           # ← actual generated route
    get: { … }
  /api/v1/auth/me:             # ← actual generated route
    get: { … }
```

**Forbidden (rely on `servers` to "add" the prefix):**

```yaml
servers:
  - url: /api/v1
paths:
  /employees:                  # WRONG — generator emits @GetMapping("/employees")
    get: { … }
```

Do NOT try to fix this with `server.servlet.context-path: /api/v1` in
`application.yml` — that conflicts with the per-app context-path (e.g.
`/employee-directory`) and forces a single global prefix that breaks
when V2 lands on `/api/v2/`.

**Review check (grep-able):** every `paths:` key must start with `/api/v`.

```bash
# Lists offending path keys (paths NOT starting with /api/v<digit>/).
awk '/^paths:/{in=1;next} /^[a-z]/{in=0} in && /^  \//{print FILENAME":"NR": "$0}' \
  backend/application/src/main/resources/api/v1/specs/openapi.yaml \
  | grep -vE '^[^:]+:[0-9]+:  /api/v[0-9]+/'
```

## Security scheme (canonical)

```yaml
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
```

Protected operations must declare `security: [{ bearerAuth: [] }]` and document
`401` and `403` responses with examples.

## Backend contract boundary (controllers MUST implement generated interfaces)

Every backend controller MUST `implements <Tag>Api` (the interface emitted
by `openapi-generator-maven-plugin` from each `tags:` entry) and override
its methods with `@Override`. Raw `@GetMapping` / `@PostMapping` /
`@RequestMapping` annotations directly on a controller class (or its
methods) are **forbidden** — they bypass the generated path / method /
parameter / response-type contract.

```java
// CORRECT — implements generated interface, no method-level routing annotations
@RestController
public class EmployeesController implements EmployeesApi {
    @Override
    public ResponseEntity<EmployeeV1> getEmployee(Long id) { ... }
}

// CORRECT — file exports keyed off `format: binary` in spec → Resource
@RestController
public class SheetsController implements SheetsApi {
    @Override
    public ResponseEntity<Resource> fetchGoogleSheetCsv(String url) { ... }
}

// FORBIDDEN — hand-written routing, no interface
@RestController
@RequestMapping("/api/v1/sheets")              // FORBIDDEN at class level
public class SheetsProxyController {
    @GetMapping("/fetch")                       // FORBIDDEN — bypasses spec
    public ResponseEntity<String> fetch(@RequestParam String url) { ... }
}
```

**Why:** the generated interface is the in-code contract surface — it
encodes every path, verb, parameter, response status, content type, and
security requirement from `openapi.yaml`. When a controller skips the
interface, the spec and the running code drift silently. The frontend's
`openapi-fetch` client keeps believing the spec; the backend serves
something else; the gap surfaces as 404 / 415 / type mismatches at the
worst possible moment.

Past failure mode: proxy endpoint authored as
`@RestController @RequestMapping("/api/v1/<aggregate>")` with method-level
`@GetMapping` instead of `implements <Tag>Api`. Spec existed; the
generated interface was just ignored. Frontend `openapi-fetch` calls
happened to line up only because the path string was hand-copied identically
into the controller. The next spec change silently desyncs the two.

**Review check (grep-able):** zero matches across the controllers folder.

```bash
# Method-level routing annotations inside controllers/ are the forbidden form;
# class-level @RequestMapping on a controller class is also banned.
grep -rn '@GetMapping\|@PostMapping\|@PutMapping\|@PatchMapping\|@DeleteMapping\|@RequestMapping' \
  backend/application/src/main/java/*/application/*/controllers/ \
  backend/application/src/main/java/*/*/controllers/
```

The only acceptable annotations on a generated-interface implementor are
`@RestController` (class) and `@Override` (each method).

## Frontend contract boundary

Frontend code must call backend operations through the generated
`openapi-fetch` client only. Raw `fetch`, `axios`, and `XMLHttpRequest` are
forbidden under `frontend/src` because they bypass generated path/method types.
This is what allows regressions such as `PATCH` when the spec defines `PUT`, or
`/usage/summary` when the spec defines `/admin/usage`.

Every Replit/frontend workflow must run `npm run generate:api` before Vite,
typecheck, tests, or build. Stale/missing `schema.d.ts` invalidates the
contract-first guarantee.

## Response Discipline

Every protected operation explicitly declares `200`/success, `400` when validation
applies, `401`, `403`, and `500` inline under the operation. Do not create
`components.responses` wrappers such as `UnauthorizedV1`, `ForbiddenV1`, or
`BadRequestV1`; Feedlot-style specs repeat the status descriptions in each
operation so the generated contract stays local and readable.

Canonical error schemas live under `components.schemas`:
- `<App>ApiExceptionResponseV1` for service/business/security/internal errors:
  `code`, `message`, `timestamp`, `correlationId`.
- `<App>ValidationExceptionResponseV1` for request validation errors: `errors`,
  `timestamp`, `correlationId`.
- `FieldToErrorResponseV1`: `code`, `field`, `error`.
- Multi-status exception schemas only when `207` is actually used.

`401` is description-only unless the application explicitly returns a body from
its auth entry point. `403`, service-level `400`, `404`, and `500` use
`<App>ApiExceptionResponseV1`. DTO/path/body validation uses
`<App>ValidationExceptionResponseV1`. If one status can legitimately return
both validation and service-level business errors, document `oneOf` inline for
that status.

## Input validation is contract validation

Every controllable API input must have an explicit OpenAPI constraint: for
example `minLength`/`maxLength`/`pattern` for strings, numeric bounds for
numbers, and item bounds for arrays. `format: email`, `format: uuid`, and a
named enum `$ref` are also explicit constraints. If an input is intentionally
unconstrained, add a meaningful `x-unconstrained-reason` beside its schema or
parameter; absence of a constraint is never implicit permission.

The generated Spring interface turns these constraints into Jakarta validation
annotations. Each constrained operation also needs a controller/MVC negative
test asserting `400 Bad Request`; `scripts/verify-gates.sh` checks both the
contract constraints and the negative-test count.

## Thin-controller review boundary

`structure-lint.sh` rejects repository access, generated DTO construction,
branches, loops, ternaries, exception handling, and stream transformations in
API controllers. `web/` infrastructure controllers (for example SPA fallback)
are explicitly outside this rule. Static checks cannot determine whether two
otherwise legal delegation calls form business orchestration; code review must
still reject controller methods that coordinate business decisions rather than
performing request extraction, one service delegation, and DTO mapping.

### File exports — binary schema -> Spring `Resource`

For CSV/XLSX/PDF/file downloads, model the response as real binary content.
With the canonical Spring generator, this produces a controller signature using
`org.springframework.core.io.Resource`.

```yaml
paths:
  /api/v1/employees/export:
    get:
      tags: [Employees]
      operationId: exportEmployees
      summary: Export employees as CSV.
      security: [{ bearerAuth: [] }]
      responses:
        "200":
          description: CSV file.
          headers:
            Content-Disposition:
              schema: { type: string }
              example: attachment; filename="employees.csv"
          content:
            text/csv:
              schema:
                type: string
                format: binary
        "401":
          description: The authorization token not provided or expired.
        "403":
          description: The authorization token not correct or user not authorized.
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/<App>ApiExceptionResponseV1"
        "500":
          description: Exception occurred while exporting the file.
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/<App>ApiExceptionResponseV1"
```

Controller implementation:

```java
@Override
public ResponseEntity<Resource> exportEmployees() {
    ByteArrayResource body = new ByteArrayResource(service.exportCsv());
    return ResponseEntity.ok()
        .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"employees.csv\"")
        .contentType(MediaType.parseMediaType("text/csv"))
        .body(body);
}
```

Forbidden:
- `ResponseEntity<byte[]>` for generated export endpoints;
- returning `String` for CSV content;
- calling `getRequest()` from the generated API interface to stream manually;
- "fixing" a `ResponseEntity<String>` generator output by switching the
  controller to hand-written `@GetMapping` instead. Past failure: a `text/csv`
  response declared as `schema: { type: string }` (without `format: binary`)
  made the generator emit `ResponseEntity<String>`; the agent then ditched
  the generated `SheetsApi` interface and wrote raw `@GetMapping` rather
  than fixing the spec. Correct response: add `format: binary` to the spec,
  regenerate, implement the now-`Resource`-typed interface.

## Schema discipline

### Closed schemas by default

Every `type: object` schema is closed by default: set
`additionalProperties: false` unless the object is intentionally a dynamic map.
This is mandatory for all top-level request and response DTOs under
`components.schemas`. Do not use loose object schemas as a shortcut for fields
that are known in the source system.

Forbidden for normal DTOs:

```yaml
CreateTeacherVideoRequestV1:
  type: object
  additionalProperties: true

TeacherVideoResponseV1:
  type: object
  additionalProperties: true
```

Correct:

```yaml
CreateTeacherVideoRequestV1:
  type: object
  additionalProperties: false
  required: [lessonId]
  properties:
    lessonId:
      type: integer
      format: int64
    avatarId:
      type: string
      nullable: true
    voiceId:
      type: string
      nullable: true

TeacherVideoResponseV1:
  type: object
  additionalProperties: false
  required: [id, status]
  properties:
    id:
      type: integer
      format: int64
    status:
      type: string
      enum: [queued, processing, completed, failed]
    videoUrl:
      type: string
      nullable: true
```

Dynamic maps are allowed only when the product behavior genuinely requires
unknown keys, for example provider metadata, arbitrary webhook payloads, JWT
claims, or permission dictionaries. Even then, keep the containing DTO closed
and type the map values as narrowly as possible. Reusable top-level dynamic
helper schemas are allowed only with explicit names such as `JsonMetadataV1`,
`JsonPayloadV1`, `ProviderPayloadV1`, `WebhookPayloadV1`, or `JwtClaimsV1`;
ordinary request/response DTO names must never be loose.

```yaml
IntegrationEventV1:
  type: object
  additionalProperties: false
  required: [provider, payload]
  properties:
    provider:
      type: string
    payload:
      type: object
      additionalProperties: true   # allowed: explicitly dynamic provider payload

PermissionsResponseV1:
  type: object
  additionalProperties: false
  required: [permissions]
  properties:
    permissions:
      type: object
      additionalProperties:
        type: boolean
```

Controller signatures generated from regular business endpoints must not use
`Map<String, Object>` / `Object` request or response bodies. If generation
produces those types, the OpenAPI schema is too loose and must be tightened
before implementation. The same applies to frontend generated types containing
`[key: string]: unknown` except for explicitly approved dynamic map fields.

**Review check (grep-able):** zero loose top-level business DTOs, every
regular object schema explicitly declares `additionalProperties: false`, and
zero generated frontend unknown index signatures for non-allowlisted schemas.

```bash
bash scripts/lib/check-openapi-strict-schemas.sh \
  backend/application/src/main/resources/api/v1/specs/openapi.yaml \
  frontend/src/shared/api/generated/schema.d.ts
```


- Every field has `type` and uses `format` where relevant (`date`, `date-time`, numeric sizes).
- Entity IDs are `type: integer, format: int64` (→ Java `Long`, Postgres `BIGINT`);
  never `format: uuid`. See `custom_instruction/instructions.md` → Database policy.
- `required` is explicit.
- Reuse schemas from `components.schemas`.
- Document enums with descriptions.
- Unique, stable `operationId` per operation.
- Every operation has both `summary` and `description`; `summary` is short,
  `description` explains behavior, authorization/business semantics, and
  important side effects.
- Every schema has `description`. Every schema property has `description`,
  including `$ref` properties. Do not rely on field names as documentation.
- Every parameter, request body, response, and enum schema has `description`.
  Enum schemas also carry `x-enumDescriptions` with one description per enum
  value when values are not self-evident.
- Generated JavaDoc is not a substitute for OpenAPI descriptions. The YAML is
  the public API contract read by frontend, Swagger UI, and downstream clients.

**Review check (grep-able):** every operation/schema/property has meaningful
description text.

```bash
bash scripts/lib/check-openapi-documentation.sh \
  backend/application/src/main/resources/api/v1/specs/openapi.yaml
```

### Enums — standalone schemas, never inline (REQUIRED)

Every enum MUST be a NAMED, VERSIONED schema under `components.schemas`, referenced via
`$ref` from every request, response, object property, array item, and query/path
parameter using it. Inline `enum: [...]` on a property or parameter is forbidden.

The version suffix is mandatory for enums too: `UserRoleCodeV1`, `LessonStatusV1`,
`MaterialKindV1`. This prevents generated inner enum types such as
`UserPermissionSnapshotV1.RoleCodeEnum` and gives mappers one reusable type for
both requests and responses.

**Why.** Spring openapi-generator handles inline vs `$ref` differently:
- **Inline** → nested inner class (`EmployeeV1.StatusEnum`); same enum in two
  DTOs → TWO unrelated inner types, not assignable.
- **`$ref`** → top-level enum class (`EmployeeStatusV1`) shared by every
  referencer. One type, reusable in mappers/repos/query params.

The `EmployeeV1.StatusEnum does not exist` MapStruct failure comes from
mixing the two. Standardise on `$ref`.

**Correct (canonical form):**

```yaml
components:
  schemas:
    EmployeeStatusV1:
      type: string
      enum: [ACTIVE, ON_LEAVE, TERMINATED]
      description: Employment status.

    EmployeeV1:
      type: object
      required: [id, fullName, status]
      properties:
        id: { type: integer, format: int64 }
        fullName: { type: string }
        status: { $ref: '#/components/schemas/EmployeeStatusV1' }

    UpdateEmployeeRequestV1:
      type: object
      properties:
        status: { $ref: '#/components/schemas/EmployeeStatusV1' }

paths:
  /employees:
    get:
      parameters:
        - in: query
          name: status
          schema: { $ref: '#/components/schemas/EmployeeStatusV1' }
```

**Forbidden (will produce inner-class enums and downstream pain):**

```yaml
# DON'T — inline enum on a property
EmployeeV1:
  properties:
    status:
      type: string
      enum: [ACTIVE, ON_LEAVE, TERMINATED]    # inline → inner class
```

**Naming.** Enum schema = `<Noun>V1` (version suffix as for DTOs).
Examples: `EmployeeStatusV1`, `PriorityV1`, `AuthModeV1`. Generator emits
Java enum with that exact name. Never refer to generated nested enum types in
production code.

**Review check:** reject every inline enum and every unversioned enum schema.

```bash
bash scripts/lib/check-openapi-enums.sh \
  backend/application/src/main/resources/api/v1/specs/openapi.yaml
```

### Enum/reference-data synchronization

Every enum-like value must be synchronized across four places in the same
change:

- OpenAPI named enum schema (`components.schemas.<StatusV1>.enum`).
- Database reference data / Liquibase seed table, when the value is stored as
  a FK or code row.
- Backend constants/mappers/query filters.
- Frontend labels, badge colors, filters, segmented controls, and mutation UI.

If OpenAPI declares `ACTIVE`, `ON_LEAVE`, `ON_VACATION`, the Liquibase seed
must contain all three reference rows and the frontend cannot render a two-way
toggle. Adding a status only in the UI or only in the DB is a contract bug:
generated clients reject it, backend validation rejects it, or the UI displays
an unknown state.

When statuses live in lookup tables, OpenAPI enum values are the public code
strings and DB rows use the same `code TEXT UNIQUE` values. Never use
PostgreSQL `CREATE TYPE ... AS ENUM`.

**Review check (grep-able):**
```bash
# Inline enums must not appear in property bodies. The only acceptable
# `enum:` line is at the top of a components.schemas entry.
awk '/^  [A-Z][A-Za-z0-9]+V[0-9]+:/{schema=1} /^    /{} /enum:/{if(!schema)print FILENAME":"NR": inline enum"}' \
  backend/application/src/main/resources/api/v1/specs/openapi.yaml
```

## Generator (Maven)

Configured inline in the canonical parent pom:
`templates/generated-project/scaffold/backend/pom.xml` (declared in
`<pluginManagement>`, activated in `application/pom.xml`).

Mandatory options:
`generatorName=spring`, `library=spring-boot`, `interfaceOnly=true`,
`useSpringBoot3=true`, `openApiNullable=false`, `skipDefaultInterface=true`,
`useTags=true`, `dateLibrary=java8-localdatetime`,
`additionalModelTypeAnnotations=@lombok.Generated` (exempts generated DTOs from JaCoCo).

**NOT** used: `modelNameSuffix`. Schema names already carry the version
suffix explicitly in the YAML (`ResourceV1`, `<App>ApiExceptionResponseV1`, etc.) — see
"Versioned DTO names" below.

### `dateLibrary=java8-localdatetime` is locked

Project-wide time type: **`LocalDateTime`** (interpreted as UTC). Every
`format: date-time` → `java.time.LocalDateTime`. Do NOT change to `java8`
(→ `OffsetDateTime`); do NOT add `<typeMappings>OffsetDateTime=LocalDateTime</typeMappings>`.

On `incompatible types: LocalDateTime cannot be converted to OffsetDateTime`
→ change hand-written code (field type → `LocalDateTime`), not the generator.

UTC convention:
- DB: `TIMESTAMPTZ` storing UTC.
- Service/controller signatures: `LocalDateTime` as UTC.
- JSON wire: ISO-8601 without offset (`2026-05-24T10:00:00`); document UTC in each field.
- Frontend: treats as UTC, converts to local only at display.

### Versioned DTO names (mandatory)

Every schema named with explicit version suffix in YAML: `ResourceV1`,
`CreateResourceRequestV1`, `<App>ApiExceptionResponseV1`. Generator emits Java class verbatim.

**Do NOT use `<modelNameSuffix>V1</modelNameSuffix>`.** A global suffix forces
every schema to the same version band — V2 typically changes ~30% of entities.
Explicit names let `ResourceV1` and `ResourceV2` coexist; global suffix forces
bumping every type at once.

Breaking V2 contract:
1. Add V2 schemas to the same `openapi.yaml` (`ResourceV2`, `CreateResourceRequestV2`).
   Keep V1 untouched.
2. Add operations under `/api/v2/...` (or split specs — two generator
   executions, separate `apiPackage`).
3. V1 endpoints/DTOs keep working; V2 emits V2 DTOs.
4. Mark V1 `deprecated: true` before sunset.

Hand-written code always uses the versioned name: `<App>ApiExceptionResponseV1 dto = new <App>ApiExceptionResponseV1()`.
There is no unversioned `ApiError` or generic response DTO in this project.

Output: `${project.build.directory}/generated-sources/openapi`. Generated
API/model/invoker packages must be separate from hand-written.

## SpringDoc

```yaml
springdoc:
  swagger-ui:
    url: /api/v1/specs/openapi.yaml
```

## Frontend contract

React frontends consume this same YAML via `openapi-typescript` +
`openapi-fetch` + TanStack Query. See
`templates/generated-project/frontend/canonical-react-frontend-rules.md`.

## Review checklist

See `templates/generated-project/openapi/openapi-review-checklist.md`.
