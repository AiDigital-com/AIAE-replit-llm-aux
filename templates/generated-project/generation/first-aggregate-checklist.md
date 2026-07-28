# First real aggregate — checklist

Run in order when landing the **first** domain feature (same commit).

1. **Clerk Secrets** — set `CLERK_*` and `AUTH_*` in Replit Secrets before Run.
2. `bash scripts/apply-package-name.sh <app-name-package>` if not done yet.
3. Decide caching once: keep the complete L2 + invalidation stack only for a
   concrete cache candidate; otherwise run
   `bash scripts/remove-cache-management.sh --apply`.
4. Read the sample aggregate under `backend/*/sample/` — copy its layer pattern.
5. OpenAPI: add endpoints to `backend/application/src/main/resources/api/v1/specs/openapi.yaml`.
6. `mvn -f backend/pom.xml -DskipTests compile` then `cd frontend && npm run generate:api`.
7. Implement generated `*Api` in `application/<aggregate>/controllers/` (≤6 lines each).
8. Add entity/repo (domain), record/mapper/service (service), Liquibase in
   `backend/migrations/src/main/resources/db/changelog/changes/`; use MapStruct
   for create/update mapping and `CurrentTime` for timestamps.
9. `bash scripts/strip-scaffold-samples.sh` — removes reference `sample/*` fixtures.
10. Fill `README.md` (purpose, API links, env vars, run steps).
11. Add tests: `*ControllerTest`, `*ServiceImplTest`, frontend flow test.
12. `bash scripts/local-verify.sh` before share/publish.

Forbidden: rename sample classes in place; leave `0002-sample-reference.xml`
in master changelog; write `new *Entity()` plus setter-chain mapping; call
`LocalDateTime.now(...)` / `Instant.now()` directly in production code.

Layer rules (on demand): `templates/generated-project/structure/near-production-project-structure.md`.
Token load order: `templates/generated-project/generation/token-efficient-generation-rules.md`.
