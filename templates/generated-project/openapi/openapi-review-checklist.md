# OpenAPI Review Checklist

Quick gate for every API change. Detailed rules in
`templates/generated-project/openapi/canonical-openapi-rules.md`.

## Contract

- [ ] `openapi` and `info.version` present
- [ ] Spec path is `src/main/resources/api/v1/specs/openapi.yaml` (NOT under `static/` — Vite build wipes that dir)
- [ ] Path/method correct, unique stable `operationId`, meaningful tags

## Request and response

- [ ] Every controllable request body property has an explicit constraint, or a
      meaningful `x-unconstrained-reason`
- [ ] Every controllable parameter has an explicit constraint, or a meaningful
      `x-unconstrained-reason`
- [ ] Each constrained operation has a negative MVC/controller test asserting
      `400 Bad Request`
- [ ] Response schema for every declared status code
- [ ] `Content-Type: application/json` unless otherwise required
- [ ] File exports/downloads use `type: string`, `format: binary` under the
      real media type (`text/csv`, XLSX/PDF media type, etc.) so Spring
      generator emits `ResponseEntity<Resource>`
- [ ] No export/download controller is expected to return `byte[]` or call
      generated-interface `getRequest()`

## Documentation

- [ ] Every operation has `summary` and behavior-focused `description`
- [ ] Every path/query/header parameter has `description`
- [ ] Every request body and response has `description`
- [ ] Every schema has `description`
- [ ] Every schema property has `description`, including `$ref` fields
- [ ] Every enum schema has `description`; non-obvious values have `x-enumDescriptions`
- [ ] Every enum is a standalone versioned `components.schemas.*V1` schema
- [ ] No property, array item, or parameter uses inline `enum`; all enum usages are `$ref`

## Schema Strictness

- [ ] Every regular `type: object` DTO is closed with `additionalProperties: false`
- [ ] No top-level request/response schema uses `additionalProperties: true`; only explicitly named dynamic helper schemas may do that
- [ ] No regular endpoint relies on `Map<String, Object>`, raw `Object`, or loose object bodies
- [ ] Dynamic maps are isolated inside closed DTOs and their values are typed as narrowly as possible
- [ ] Generated frontend schema has no top-level `[key: string]: unknown` except approved dynamic helper schemas

## Errors

- [ ] Explicit `4xx`/`5xx` for expected failures
- [ ] Shared error schema across operations
- [ ] At least one error example per operation

## Security (when protected)

- [ ] `bearerAuth` exists in `components.securitySchemes`
- [ ] Operation declares `security`
- [ ] Explicit `401` and `403` responses
- [ ] `/api/v1/auth/me` documented (no mock-login endpoint — Clerk SSO only)

## Examples

- [ ] Success example
- [ ] Validation-error example
- [ ] Business-error example (when relevant)

## Compatibility

- [ ] No silent breaking changes
- [ ] Deprecations marked
- [ ] Migration note for any breaking change
