---
name: engineering-handoff
description: Final handoff checklist when transferring an accepted MVP to an engineering team for long-term ownership. Use when the user says the project is being shipped to engineering, handed off, or moved out of the Replit MVP phase. Builds on top of mvp-safety-review and only adds migration-to-production delta.
metadata:
  user-invocable: "true"
---

# Engineering Handoff

Use when the MVP is accepted and must move to long-term engineering ownership.
Runs *after* `mvp-safety-review`; does not duplicate its checks.

## Prerequisites

Two, both blocking.

1. **Coverage is finalized.** `.template-phase` must read `engineering`, and the
   strict gate (0.80 line / 0.70 branch) must pass with a bare
   `mvn -f backend/pom.xml clean verify` — no `-Pmvp`. If the phase still reads
   `mvp`, run the `finalize-coverage` skill first;
   `prepare-engineering-handoff.sh` will refuse to run until it is done. There is
   no override, and lowering the thresholds is rejected by
   `scripts/lib/check-coverage-integrity.sh`.

2. **`mvp-safety-review` passes.** All of its checks, before this skill applies.
   If that skill is not installed here, treat its absence as a blocker and say
   so — do not substitute an ad-hoc review for the publish gate.

## Remove MVP usage logging

MVP usage logging exists to measure and review the testing/feedback phase. It
must not cross the engineering handoff boundary.

Before applying the handoff cleanup:

1. Run `bash scripts/remove-usage-logging.sh`.
2. If it reports `UsageAttributes`, a custom `UsageEventSink`, or another
   semantic dependency, remove that telemetry-only field/constructor
   dependency/call deliberately. Do not delete surrounding business logic.
3. Repeat the dry run until it validates.

`bash scripts/prepare-engineering-handoff.sh --apply` then performs the validated removal
itself before running strict verification. It removes the
`event-logging-to-db-feature` Maven module, all safe `@LogUsage` imports and
annotations, usage-logging configuration/environment entries, the
`0001-usage-events.xml` migration, and the standard BigQuery usage sink when
installed. It fails if application Java still references the removed surface.
Removing the historical migration prevents fresh databases from creating the
table. It does not connect to or erase an existing database; record an explicit
retain/archive/drop decision for any existing `usage_events` data.

## Remove the frontend feature template

`frontend/src/features/_template/` (and the legacy plural `_templates/`) is
copyable teaching material, not product source. Replace its
`TemplateProfilePanel` import and route with real product features before
handoff. The handoff command blocks while application code still references
the template, then removes the reserved directory before final verification.
It never guesses how to rewrite product routes.

## Replit control-plane removal

Run `bash scripts/prepare-engineering-handoff.sh` to remove Replit
control-plane artifacts from the project:

Removed:
- `AGENTS.md`
- `replit.md`
- `.agents/`
- `custom_instruction/`
- `templates/`

Preserved:
- `CLAUDE.md`
- `.claude/` — rules, agent docs, skills, and task artifacts all survive handoff

The script is dry-run by default: it validates both telemetry and control-plane
removal, prints what it would remove, and exits.
Re-run it with `--apply` to perform the removal. It refuses to run outside a
clean Git repository and runs `bash scripts/local-verify.sh` itself immediately
before deletion, so changing `.template-phase` or writing a marker file cannot
authorize cleanup.

Confirm the script reports success and that no control-plane file remains.
The resulting repository is a clean engineering/customer transfer repo with
only the Claude Code surface intact. Do not skip this step — a handed-off repo
must not reference Replit template internals.

## Required handoff report

Record the `mvp-safety-review` result, usage-logging removal result, validation
commands and outcomes, the handoff-script dry-run/apply result, removed Replit
artifacts, preserved Claude artifacts, known limitations, and any skipped
environment checks. Do not claim Docker or deployment validation without
evidence.

## Handoff package

- [ ] README: purpose, owner, run/deploy steps for both Replit and local-dev,
      API overview, Swagger/OpenAPI links, known limitations.
- [ ] `.env.example` with safe placeholders for every consumed variable.
- [ ] Architecture summary (one page).
- [ ] List of mocked components and what must replace each one.
- [ ] Data source inventory lists all remaining external APIs and records
      whether an existing MVP `usage_events` table was retained, archived, or
      removed. Fresh schemas omit it after handoff.
- [ ] Usage logging removal result and any production analytics replacement
      decision.
- [ ] `frontend/src/features/_template/` and `_templates/` are absent, and the
      application has no scaffold `TemplateProfilePanel` import.
- [ ] README and architecture/data documentation no longer claim that the
      removed module, `@LogUsage`, or `usage_events` runtime exists. Historical
      migration notes may name them only as explicitly removed MVP components.

## Build / quality (Phase 3 — strict)

Canonical: `.claude/rules/20-tests.md`.

- [ ] `bash scripts/local-verify.sh` passes while `.template-phase` is
      `engineering`; this uses the strict default `0.80` line / `0.70` branch
      JaCoCo gate. The handoff command reruns it before cleanup.
- [ ] Integration tests with Testcontainers Postgres present and green
      (`*IT.java`, run via Failsafe).
- [ ] Frontend builds clean (`npm run check:api && npm run build`).
- [ ] Checkstyle gate enforced.
- [ ] `git-commit-id-maven-plugin` present in all module POMs.
- [ ] OpenAPI generator plugin configured per canonical rules.
- [ ] PostgreSQL types follow `BIGINT` / `TEXT` policy.
- [ ] No `<excludes><exclude>**</exclude></excludes>` or coverage-disabling
      tricks were added just to clear the 0.80 gate.

## Local-dev dry run (must succeed on a clean machine)

```bash
docker compose --profile local config
docker compose --profile local up --build -d
curl -f http://localhost:8080/<app-context-path>/actuator/health
curl -f http://localhost:8080/<app-context-path>/actuator/prometheus
docker compose --profile local down -v
```

If the dry run cannot run in the current environment, document the reason and
exact commands in README.

## Post-acceptance ownership

The strict gate is already the Maven default. Keep `.template-phase` set to
`engineering`; the `mvp` profile remains only as an auditable build-phase
mechanism and must never be reactivated after handoff. The receiving team may
replace `.claude/rules/20-tests.md` through its normal architecture-decision
process.

## Migration notes for engineering

Document the replacement plan for each item:

| From (MVP) | To (production) |
|---|---|
| Mock/stub data providers | Real integrations or documented stubs with env flags |
| Demo datasets / fixtures | Approved production data APIs/pipelines |
| Replit Secrets | Company secret manager |
| Replit-native PostgreSQL module | Managed PostgreSQL (RDS / CloudSQL / equivalent) |
| Replit Reserved VM (`deploymentTarget = "gce"`) | Target infrastructure (k8s / ECS / managed app platform) |
| MVP `usage_events` in app DB | Feature code and future-schema migration are removed at handoff. Explicitly retain, archive, or drop any table/data already created; add a production analytics sink only through an engineering decision. |
