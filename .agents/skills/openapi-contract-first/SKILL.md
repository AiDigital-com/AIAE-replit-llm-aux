---
name: openapi-contract-first
description: Contract-first OpenAPI workflow for any backend API change in a generated project. Use whenever adding, changing, deprecating or removing a REST endpoint. Drives backend interface and frontend type regeneration.
metadata:
  user-invocable: "true"
---

# OpenAPI Contract First

OpenAPI YAML is the source of truth. Implementation follows the spec, never the
reverse.

## Canonical references

- Rules: `templates/generated-project/openapi/canonical-openapi-rules.md`
- Review checklist: `templates/generated-project/openapi/openapi-review-checklist.md`
- Generator plugin (inline in parent pom): `backend/pom.xml`
- Frontend rules: `templates/generated-project/frontend/canonical-react-frontend-rules.md`
- Auth contract: `templates/generated-project/auth/google-sso-clerk-blueprint.md`

## Workflow

1. Identify affected operations/resources.
2. Update `openapi.yaml` first.
3. Run the review checklist (every operation must pass).
4. Regenerate backend interfaces via `openapi-generator-maven-plugin`.
5. Regenerate frontend types via `npm run generate:api` (when frontend exists).
6. Implement generated interfaces; add/adjust tests for contract compliance.

## Auth addendum

When the endpoint is protected: bearer JWT scheme declared,
operation has `security:`, `401`/`403` documented with payload examples,
and `/api/v1/auth/me` is present (Clerk SSO only — no mock-login endpoint).

## Compatibility

No silent breaking changes. Deprecate explicitly. Removals/breaks need a
migration note in the contract and a version bump.

## Definition of done

- OpenAPI updated and review checklist passes.
- Backend interfaces regenerated and implemented.
- Frontend types regenerated when frontend exists.
- Tests cover changed contract behavior (success, validation, auth, error shape).
