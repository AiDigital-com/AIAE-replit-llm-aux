# Publish Gate Checks

Detailed grep commands for MVP safety review. Loaded on demand from mvp-safety-review/SKILL.md.


## Usage logging

Canonical: `templates/generated-project/observability/usage-logging-rules.md`.

- [ ] `USAGE_LOGGING_ENABLED`, `USAGE_LOG_SERVICE_NAME`, `USAGE_LOG_ENVIRONMENT` in `.env.example`.
- [ ] Liquibase changelog for `usage_events` runs at startup.
- [ ] `spring-boot-starter-aop` declared (enables `UsageLoggingAspect`).
- [ ] `UsageLoggingAspect` + `@LogUsage` annotation files present.
- [ ] `PostgresUsageLogger` binds when enabled; `NoOpUsageLogger` otherwise.
- [ ] Usage persistence runs through a separate bean with
      `@Async("usageLoggingExecutor")` and `@Transactional(REQUIRES_NEW)`;
      `@Transactional` is NOT on `UsageLoggingAspect`.
- [ ] `usage_events.attributes` is `jsonb` in Liquibase and
      `Map<String,Object>` + `@JdbcTypeCode(SqlTypes.JSON)` in JPA.
- [ ] Logger never blocks / fails user requests; insert errors are swallowed.
- [ ] `app.usage-logging.service-name` resolves to a real, non-placeholder
      value (NOT empty, NOT `replit-mvp-template`). Empty service-name +
      `enabled=true` must FAIL FAST at startup, not silently bind NoOp:
      ```bash
      # service-name in application.yml must NOT default to "" or to the
      # template placeholder. Should be `${spring.application.name}` or a
      # concrete app identifier.
      grep -E 'service-name:.*\$\{USAGE_LOG_SERVICE_NAME:\}' \
        backend/application/src/main/resources/application*.yml \
        && echo "REJECT: empty default for USAGE_LOG_SERVICE_NAME"
      grep -E 'spring\.application\.name:\s*replit-mvp-template' \
        backend/application/src/main/resources/application*.yml \
        && echo "REJECT: spring.application.name still at template placeholder"
      ```
- [ ] Frontend never reaches `usage_events` directly.
- [ ] **Usage logging is auto-applied** — the aspect intercepts every public
      `*ServiceImpl` method, so no per-method annotation is needed. Verify the
      auto-intercept pointcut is intact (not reverted to `@annotation`):
      ```bash
      grep -q 'services.impl.\*ServiceImpl' \
        backend/event-logging-to-db-feature/src/main/java/*/usagelogging/UsageLoggingAspect.java \
        || echo "REVERTED: usage-logging aspect no longer auto-intercepts service impls"
      ```
- [ ] No direct `usageLogger.record(...)` in business code:
      ```bash
      grep -rEn 'usageLogger\.record\(' backend/service backend/application/src/main/java/*/[!observability]*
      ```

## Backend / frontend quality

- [ ] OpenAPI contract updated for any API change; spec at `src/main/resources/api/v1/specs/openapi.yaml` (NOT under `static/`).
- [ ] `openapi-generator-maven-plugin` configured.
- [ ] Frontend uses `openapi-typescript` + `openapi-fetch` + TanStack Query.
- [ ] Frontend follows Elevate visual rules and has no left side menu/sidebar:
      ```bash
      grep -RInE 'Sidebar|SideNav|LeftNav|side-nav|side-menu|left-nav|left-menu|app__sidebar|layout__sidebar' frontend/src
      ```
- [ ] Frontend renders the actual app, not a Replit port-switch placeholder:
      ```bash
      grep -RInE 'React dev server is running|Switch the preview pane to port 5173|Open on port 5173' frontend/src
      ```
      Expected: empty.
- [ ] Frontend UI rules pass: no raw `px`/hex drift, reset keeps long strings
      and button labels safe, and generated forms expose accessible validation:
      ```bash
      bash scripts/lib/check-frontend-ui-rules.sh
      ```
- [ ] Generated forms validate OpenAPI-required fields before submit and have
      tests for a missing required field plus one long-string/responsive layout
      case. Check mobile and desktop widths for changed form screens.
- [ ] Reference/status values are synchronized across OpenAPI enum, Liquibase
      seed/reference data, backend mappers/constants, and frontend labels/badges
      / controls. A three-value enum must not have a two-way toggle.
- [ ] `frontend/package-lock.json` exists and is committed — enterprise
      reproducibility requires a pinned lockfile, not just version ranges:
      ```bash
      test -f frontend/package-lock.json || echo "REJECT: frontend/package-lock.json missing — run 'cd frontend && npm install' and commit it"
      ```
- [ ] Structured JSON logs to stdout; Actuator `health` + `prometheus` reachable through context-path.
- [ ] Checkstyle and JaCoCo plugins wired; phase-aware verification enforces the
      committed non-zero MVP floor — see Tests.

## Tests (publish gate — hard reject if missing)

Canonical: `templates/generated-project/testing/testing-policy.md`. Past
runs skipped Phase 2 and shipped with zero tests.

- [ ] Test files exist (zero tests with controllers present = reject):
      ```bash
      find backend -path '*/src/test/java/*' -name '*Test.java' -o -name '*IT.java' | wc -l
      ```
- [ ] Every `*Controller.java` has a matching test:
      ```bash
      for c in $(find backend/application/src/main/java -name '*Controller.java'); do
        name=$(basename "$c" .java)
        find backend -name "${name}Test.java" | grep -q . || echo "MISSING: ${name}Test.java"
      done
      ```
- [ ] Every `*ServiceImpl.java` has a matching test:
      ```bash
      for s in $(find backend/service/src/main/java -name '*ServiceImpl.java'); do
        name=$(basename "$s" .java | sed 's/Impl$//')
        find backend -name "${name}Test.java" -o -name "${name}ImplTest.java" | grep -q . || echo "MISSING test for: $name"
      done
      ```
- [ ] At least one application/health smoke test exists:
      ```bash
      find backend -path '*/src/test/java/*' \( -iname '*Application*Test.java' -o -iname '*Health*Test.java' -o -iname '*SmokeTest.java' \) | wc -l
      ```
- [ ] At least one Liquibase smoke test (`@DataJpaTest` running master changelog).
- [ ] `bash scripts/local-verify.sh` passes locally with the committed coverage
      phase (MVP or engineering).
- [ ] Frontend behavior tests exist when frontend logic exists:
      ```bash
      find frontend/src \( -name '*.test.ts' -o -name '*.test.tsx' \) | wc -l
      ```
- [ ] Frontend tests and build pass:
      ```bash
      cd frontend && npm test && npm run build
      ```
- [ ] No commit removed existing tests just to clear CI.

The `engineering` phase (`bash scripts/local-verify.sh`, strict `0.80`/`0.70`)
is the handoff bar, not MVP publish.

## Replit deployment readiness

Canonical: backend SKILL → "Port architecture lock" + replit.md → "Replit deployment model".

### Workspace + Deployment config

- [ ] `.replit` + `replit.nix` present and the workspace runs.
- [ ] `.replit` `[env]` sets `SPRING_PROFILES_ACTIVE = "replit"` and `PORT = "5000"`.
- [ ] `.replit` `[deployment].deploymentTarget = "gce"` (Reserved VM), not Autoscale.
- [ ] `.replit` `onBoot` runs `bash scripts/setup-project.sh`.
- [ ] Build command (`mvn -DskipTests package` + frontend-maven-plugin build) succeeds in CI.
- [ ] Deployment Secrets pane has copies of `SPRING_PROFILES_ACTIVE`, `CLERK_*`, `AUTH_*`,
      `USAGE_LOG_*` (workspace `[env]` does NOT propagate).

### Port architecture lock (hard reject)

Past runs swapped Vite onto 5000 + Spring to 8080 → broke Reserved-VM Deployment.

- [ ] `.replit` `[[ports]]` has EXACTLY ONE entry: `5000 → 80`. Vite 5173
      is workspace-only; adding a `[[ports]]` for it exposes 5173 externally
      in deployment where Vite isn't running.
- [ ] `application-replit.yml` uses `server.port: ${PORT:5000}` — not hard-coded:
      ```bash
      grep 'server.port:' backend/application/src/main/resources/application-replit.yml
      ```
- [ ] `application-replit.yml` sets datasource directly from Replit PG* env vars:
      ```bash
      grep -E 'PGHOST|PGPORT|PGDATABASE|PGUSER|PGPASSWORD' \
        backend/application/src/main/resources/application-replit.yml
      ```
- [ ] No `ReplitDatabaseUrlPostProcessor`, `.imports`, or `spring.factories`
      datasource hook. Direct YAML is the canonical Replit path:
      ```bash
      grep -rE 'ReplitDatabaseUrlPostProcessor|EnvironmentPostProcessor.imports|spring.factories' \
        backend/application/src/main/
      ```
- [ ] No forced `sslmode=require` in app config. Current Replit Postgres works
      without SSL unless the actual env explicitly requires it:
      ```bash
      grep -rEn 'sslmode=require' backend/application/src/main/resources/
      ```
- [ ] `vite.config.ts` uses `port: 5173 + strictPort: true` (NOT 5000):
      ```bash
      grep -E 'port: *5(000|173)' frontend/vite.config.ts
      ```
- [ ] `vite.config.ts` `server.allowedHosts` covers `.replit.dev`, `.repl.co`,
      `.kirk.replit.dev` (otherwise Vite 5+ returns "Blocked request"):
      ```bash
      grep -E 'allowedHosts|replit\.dev' frontend/vite.config.ts
      ```
- [ ] No `start.sh` at project root:
      ```bash
      [ -f start.sh ] && echo "REJECT" || echo "OK"
      ```

### Local-dev artifacts

- [ ] `backend/Dockerfile` (multi-stage Maven → JRE).
- [ ] `frontend/Dockerfile` (Node → nginx static).
- [ ] `frontend/nginx.conf.template` (SPA routing + `/api` proxy).
- [ ] `docker-compose.yml` at project root with `local` profile, `postgres + backend + frontend`
      services, build contexts at `./backend` and `./frontend`.
- [ ] Local dry-run commands documented in README.

### HikariCP pool sizes

- [ ] `replit` profile: HikariCP `maximum-pool-size: 2-3` (Replit SQL Database has a low conn ceiling).
- [ ] `local` profile: HikariCP `maximum-pool-size: ~50`.

## Agent lifecycle and template-source leak (hard reject)

An active generated project commits both native agent surfaces. Only canonical
template sources are excluded; engineering handoff removes the Replit runtime
later through `prepare-engineering-handoff.sh`.

- [ ] Canonical source paths are NOT tracked by git (if anything prints, run
      `bash scripts/setup-project.sh`):
      ```bash
      git ls-files templates custom_instruction 2>/dev/null
      ```
- [ ] Active runtime paths ARE tracked:
      ```bash
      git ls-files AGENTS.md replit.md .agents/skills .claude/skills
      ```
- [ ] `.gitignore` excludes `templates/` and `custom_instruction/`, but does not
      exclude `AGENTS.md`, `replit.md`, or `.agents/`.

## Stack lock check (hard reject)

Repo must NOT contain any of:

- `main.py`, `requirements.txt`, `Pipfile`, `pyproject.toml`, `uv.lock`, `poetry.lock`,
  `manage.py`, `wsgi.py`, `asgi.py` (Python or Replit's auto-injected defaults).
- Root-level `package.json` declaring `express` / `fastify` / `koa` / `@nestjs/core` / `next`.
- `go.mod`, `Gemfile`, `composer.json`, `Cargo.toml`, `mix.exs` (other backends).
- Backend code outside `backend/` Maven module.
- `.replit` `modules` containing `python-*`.
- `.replit` `[agent] integrations` containing `flask_*`, `django_*`, `fastapi_*`.

Any match → stack lock violated. Delete offending files/lines, regenerate from
the generated project root (`backend/`, `frontend/`, and `scripts/`).

## Parent pom location

- [ ] Parent `<groupId>` and every application Java package use the fixed
      namespace `com.aidigital.<app-name-package>.*`:
      ```bash
      sed -n 's:.*<groupId>\(.*\)</groupId>.*:\1:p' backend/pom.xml | head -n 1
      grep -RInE '^package (org\.example|com\.example|io\.replit|demo|[a-z][a-z0-9_]*);' \
        backend/application/src/main/java backend/service/src/main/java backend/domain/src/main/java
      ```
      Expected for grep: empty.
- [ ] Parent `pom.xml` at `backend/pom.xml` — **not** at project root.
- [ ] Module paths in `backend/pom.xml` are relative to `backend/`
      (e.g. `<module>application</module>`, not `<module>backend/application</module>`).
- [ ] Child module poms use `<relativePath>../pom.xml</relativePath>`.
- [ ] No empty Maven modules. Every `<module>` in `backend/pom.xml` owns
      real source/resources/tests beyond `pom.xml`:
      ```bash
      for m in $(sed -n 's:.*<module>\(.*\)</module>.*:\1:p' backend/pom.xml); do
        find "backend/$m" -mindepth 2 -type f ! -path "*/target/*" | grep -q . \
          || echo "EMPTY MODULE: $m"
      done
      ```
      Expected: empty.
- [ ] `external-services` is optional. If there are no outbound integrations
      (HTTP APIs, queues, vendor SDKs, BigQuery clients, etc.), there must be
      no `backend/external-services`, no `<module>external-services</module>`,
      no dependency-management entry for it, and no `service` dependency on it.

## Error handling: single `ErrorReason` enum (hard reject)

Canonical: `templates/generated-project/errors/error-handling-pattern.md`.

- [ ] Exactly ONE `ErrorReason.java` at
      `backend/service/src/main/java/<base>/service/common/error/`:
      ```bash
      find backend -name 'ErrorReason.java' -type f   # expected: 1 line
      ```
- [ ] NO per-domain enums or legacy files:
      ```bash
      find backend -name '*ErrorReason.java' -type f | grep -v 'common/error/ErrorReason.java'
      find backend -name '*ErrorCode*.java' -o -name 'CommonErrorCodes.java'
      ```
- [ ] NO `AppErrorReason` interface (prior scaffold; removed):
      ```bash
      grep -rln 'interface AppErrorReason' backend
      ```
- [ ] NO `throw new ResponseStatusException` / `IllegalStateException` /
      `IllegalArgumentException` / `RuntimeException` in service/controller:
      ```bash
      grep -rEn 'throw new (ResponseStatus|IllegalState|IllegalArgument|Runtime)Exception' \
        backend/service backend/application
      ```
- [ ] Single `@RestControllerAdvice` (`GlobalExceptionHandler`) in `application/`
      maps every `AppException` → `ApiErrorV1`.
- [ ] No raw `Map<String,Object>` error bodies.

## Thin controllers (hard reject)

Controllers do ONLY: principal extraction → one service call → mapper → return.
Full rule in backend SKILL.

- [ ] No `*Repository` field in any controller:
      ```bash
      grep -rEn 'private final.*Repository' backend/application/src/main/java/**/controllers/
      ```
      Expected: empty.
- [ ] No `if`/`switch`/`for`/`while`/`try`/`catch` in controller method bodies:
      ```bash
      grep -rEn '^\s+(if|switch|for|while|try|catch)\b' backend/application/src/main/java/**/controllers/*.java
      ```
      Expected: empty (review false positives).
- [ ] No manual DTO construction:
      ```bash
      grep -rEn 'new .*V1\(\);' backend/application/src/main/java/**/controllers/
      ```
      Expected: empty. All DTO construction goes through `*ApiMapper`.
- [ ] Two MapStruct mappers per resource exist: `Entity ↔ ServiceRecord` in `service/`,
      `ServiceRecord ↔ ApiDto` in `application/`.
- [ ] Entities never appear as parameters or return types outside `service/`.

## Module isolation (architectural — hard reject)

- [ ] `backend/service/pom.xml` does NOT declare spring-security / oauth2 / web / servlet-api:
      ```bash
      grep -E 'spring-(security|boot-starter-(security|oauth2|web))|servlet-api' backend/service/pom.xml
      ```
      Expected: empty. Service is business orchestration — it does not know about HTTP/JWT.
- [ ] `backend/service/` source contains no `SecurityContextHolder`, `Authentication`,
      `Jwt`, or `@AuthenticationPrincipal`. Service methods that need the caller take an
      `AppUser` parameter; the controller does the JWT → AppUser conversion.
- [ ] `backend/application/` controllers implement generated OpenAPI
      signatures exactly: no `@AuthenticationPrincipal` method params and no
      direct `getRequest()` calls from generated interfaces.
      ```bash
      grep -RIn '@AuthenticationPrincipal' backend/application/src/main/java
      grep -RInE '(^|[^.[:alnum:]_])getRequest[[:space:]]*\(' backend/application/src/main/java
      ```
      Expected: empty. Use `SecurityContextHolder` + `AppUserFactory` for caller identity.
- [ ] File export endpoints use OpenAPI `type: string`, `format: binary` and
      `ResponseEntity<Resource>`, not `ResponseEntity<byte[]>`.
      ```bash
      grep -RInE 'ResponseEntity<[[:space:]]*byte\[\]|ResponseEntity<byte\[\]>' backend/application/src/main/java
      ```
      Expected: empty.
- [ ] If `backend/external-services/pom.xml` exists, it declares no internal-module deps:
      ```bash
      test ! -f backend/external-services/pom.xml || \
        grep -E '<artifactId>(domain|service|application|migrations)</artifactId>' backend/external-services/pom.xml
      ```
      Expected: empty. external-services is a true leaf and exists only with real clients.
- [ ] `backend/domain/pom.xml` does NOT depend on `service` / `application` / `external-services` / `migrations`.
- [ ] AppException family lives at `service/<base>/service/common/error/`, not `domain/common/error/`:
      ```bash
      find backend -path '*/domain/common/error/*' -name '*.java'
      ```
      Expected: empty.
- [ ] `LogUsage.java` lives in the self-contained `event-logging-to-db-feature` module:
      ```bash
      find backend -name LogUsage.java
      ```
      Expected: exactly one line under `backend/event-logging-to-db-feature/.../usagelogging/LogUsage.java`.
- [ ] Scaffold sample aggregate stripped before publish:
      ```bash
      find backend/domain/src/main/java -type d -path '*/domain/sample'
      find backend/service/src/main/java -type d -path '*/service/sample'
      grep '0002-sample-reference.xml' backend/migrations/src/main/resources/db/changelog/db.changelog-master.xml
      ```
      Expected: all empty / no matches. Run `bash scripts/strip-scaffold-samples.sh` if not.
- [ ] Controllers live under `*/controllers/` and implement generated `*Api` (no ad-hoc `@RequestMapping`):
      ```bash
      find backend/application/src/main/java -name '*Controller.java' ! -path '*/controllers/*' ! -path '*/web/*'
      grep -RInE '@(RequestMapping|GetMapping|PostMapping)' backend/application/src/main/java/*/controllers
      ```
      Expected: empty.
- [ ] When `external-services` exists: `service→external-services` present, `application→external-services` absent:
      ```bash
      test ! -f backend/external-services/pom.xml || grep -q external-services backend/service/pom.xml
      test ! -f backend/external-services/pom.xml || ! grep -q external-services backend/application/pom.xml
      ```
- [ ] Frontend router/auth shell in `frontend/src/app/AppRoot.tsx` (not `ClerkProvider` in `main.tsx`):
      ```bash
      test -f frontend/src/app/AppRoot.tsx
      ! grep ClerkProvider frontend/src/main.tsx
      ```

## Package layout (hard reject)

Plural = collections, singular = namespaces. Agent defaults to singular →
silently fragments codebase. Reject.

- [ ] Each domain aggregate in `service/` has `services/`, `services/impl/`, `mappers/`, `models/`:
      ```bash
      for d in backend/service/src/main/java/*/service/*/ ; do
        for sub in services services/impl mappers models; do
          [ -d "$d$sub" ] || echo "MISSING: $d$sub"
        done
      done | grep -v common
      ```
      Expected: no MISSING lines.
- [ ] No singular versions (`service/`, `mapper/`, `model/`, `entity/`, `repository/`, `controller/`) anywhere:
      ```bash
      find backend -type d \( -name 'service' -path '*/sample/service' \
          -o -name 'mapper' -o -name 'model' \
          -o -name 'entity' -o -name 'repository' \
          -o -name 'controller' \) | grep -v 'src/main/java/[^/]*$'
      ```
      Expected: empty.
- [ ] Each `domain/` aggregate has `entities/` + `repositories/`:
      ```bash
      for d in backend/domain/src/main/java/*/domain/*/ ; do
        [ -d "${d}entities" ]    || echo "MISSING entities/ under $d"
        [ -d "${d}repositories" ] || echo "MISSING repositories/ under $d"
      done
      ```
      Expected: no MISSING lines.

## Build flags (hard reject)

Past Agent runs typed `-Dcheckstyle.skip=true` and forgot to remove it.

- [ ] `.github/workflows/ci.yml` has no `-Dcheckstyle.skip`, `-Djacoco.skip`,
      `-Dmaven.test.skip`, `-Dopenapi.skip`.
- [ ] No Makefile / script invokes Maven with these flags.
- [ ] README doesn't recommend skipping gates:
      ```bash
      grep -rE 'checkstyle\.skip|jacoco\.skip|maven\.test\.skip|openapi\.skip' .
      # matches under templates/ and .claude/ are rule statements, not violations
      ```

## Database

- [ ] No `CREATE TYPE … AS ENUM` in changelogs. Dictionary data lives in
      `<thing>_status` / `<thing>_kind` tables with `BIGINT id` + `TEXT code` + `TEXT name` + FK.
- [ ] IDs are `BIGINT`, strings are `TEXT`, no `VARCHAR`.

## Non-publish conditions (any one blocks)

- Source contains tokens / passwords / private keys / service-account JSON.
- Production credentials required to run the local demo.
- No working auth path when SSO keys are absent.
- App relies on undocumented manual setup.
- Backend is not Java + Spring Boot + Maven (see Stack lock check above).
