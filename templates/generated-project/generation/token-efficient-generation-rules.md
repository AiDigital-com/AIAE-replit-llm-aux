# Token-Efficient Generation Rules

Generate projects by reusing canonical artifacts and codegen. Do not retype.

## Agent load order (first feature — max ~5 files)

1. `custom_instruction/instructions.md` (always loaded by Replit)
2. `templates/generated-project/generation/first-aggregate-checklist.md`
3. `.claude/skills/openapi-contract-first/SKILL.md` **or** `frontend-react-feature/SKILL.md`
4. One canonical topic file only if needed (OpenAPI rules **or** structure anti-patterns)
5. Copy from `templates/generated-project/scaffold/` — never paste canonical docs inline

Do **not** load `near-production-project-structure.md`, `usage-logging-rules.md`, and
`publish-gate-checks.md` in the same turn unless implementing that specific concern.
Load `performance/performance-engineering-rules.md` only when the task changes
request/query/transaction/cache/pool/payload/loading behavior or performs a
performance review.

## Hard rules

- Do not duplicate canonical content. Reference instead.
- OpenAPI YAML is the single source of API truth — backend interfaces and
  frontend types are generated from it.
- Generated code lives in dedicated folders. Never mix with handwritten code.
- Do not paste generated OpenAPI/DTO bodies into explanations or READMEs.
- Do not scaffold unused screens, endpoints, entities, DTOs, repositories.
- Do not include large fixture datasets inline; use small fixtures.
- Do not commit service account JSON. Env placeholders only.
- Copy scaffold files — never run `npm create vite` or Spring Initializr.
- Use `shared/api/client.ts` only — no raw `fetch` / `axios` in `frontend/src`.
- Run `apply-package-name.sh` once; never hand-rename only some `PACKAGE_REPLACE_ME` dirs.
- Keep reusable outbound metrics in `backend/observability`, declare Lombok in
  every Maven submodule, and route third-party Spring HTTP through the
  Logbook-and-metrics-interceptor-enabled pooled factory.

## Recommended order

1. Root structure + mandatory files (see
   `templates/generated-project/structure/near-production-project-structure.md`).
2. `bash scripts/apply-package-name.sh <app-name-package>`.
3. OpenAPI YAML with only the endpoints the feature needs.
4. Backend `openapi-generator-maven-plugin` + interface implementations.
5. Frontend `openapi-typescript` + typed client.
6. Feature code over generated types.
7. Persistence (Liquibase + JPA) only when needed.
8. `strip-scaffold-samples.sh` when the first real aggregate replaces `sample/*`.
9. Tests for changed behavior.
10. `bash scripts/local-verify.sh` (includes `structure-lint.sh`) before share.

See also: `generation/first-aggregate-checklist.md`.

## Preferred codegen

- Backend: `openapi-generator-maven-plugin`, `interfaceOnly=true`.
- Frontend: `openapi-typescript` + `openapi-fetch`.
- Server state: TanStack Query wrappers around the generated client.
- UI states: reuse `LoadingBlock`, `ErrorAlert`, `EmptyState` from scaffold.
- Auth: `AuthProvider` + `ProtectedRoute` in `app/AppRoot.tsx` — Clerk SSO only.
- Layout: `AppShell` + `AppHeader` + `PageHeader`; features under `src/features/`.

Keep generated surface small, typed and inspectable.
