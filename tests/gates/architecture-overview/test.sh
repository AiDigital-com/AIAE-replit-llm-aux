#!/usr/bin/env bash
# Fixture tests for the generated-project architecture overview gate.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "${HERE}/../../.." && pwd)"
GATE="${REPO}/templates/generated-project/scaffold/scripts/lib/check-architecture-overview.sh"
. "${HERE}/../lib/assert.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

run_gate() { VERIFY_ROOT="$1" bash "${GATE}"; }

write_valid_doc() {
  local dir="$1"
  mkdir -p "${dir}/docs"
  cat > "${dir}/docs/architecture-overview.md" <<'EOF'
# Product Architecture Overview

## Document status
- Lifecycle phase: Engineering
- Last verified against: test-revision
- Cache status: enabled
- MVP usage telemetry: removed

## Product and system context
Verified product context.

## Product-specific evidence
- Product capability: Review and manage product records
- Primary users: Product operations staff
- Primary production flow: Authenticated record review
- Evidence path: `frontend/src/App.tsx`
- Evidence path: `backend/application/src/main/resources/api/v1/specs/openapi.yaml`

## Runtime and deployment
The application is built as a Spring Boot service and a BrowserRouter SPA for
local Docker and Replit deployment.
- Evidence: `.replit`

## Repository and module boundaries
| Area | Responsibility |
|---|---|
| `backend/domain` | Persistence |
| `backend/migrations` | Schema migrations |
| `backend/observability` | Runtime telemetry |
| `backend/cache-management` | Cache lifecycle |
| `backend/service` | Business use cases |
| `backend/application` | Runtime composition |
- Evidence: `backend/pom.xml`

## Primary runtime flows
An authenticated browser request enters through the generated OpenAPI boundary,
delegates to the service layer, and persists through the domain module.
- Evidence: `frontend/src/App.tsx`

## API and security boundaries
The OpenAPI document defines the HTTP contract and secured operations.
- Evidence: `backend/application/src/main/resources/api/v1/specs/openapi.yaml`

## Data ownership and migrations
Liquibase owns the ordered PostgreSQL schema lifecycle.
- Evidence: `backend/migrations/src/main/resources/db/changelog/db.changelog-master.xml`

## Caching and consistency
The enabled L2 cache uses application configuration and persisted cross-node invalidation.
- Evidence: `backend/application/src/main/resources/application.yml`

## External integrations
Local integration configuration is declared without committed secrets.
- Evidence: `.env.example`

## Observability and operations
Runtime logging is configured centrally for the Spring Boot application.
- Evidence: `backend/application/src/main/resources/logback-spring.xml`

## Decisions, constraints, and known risks
Verified decisions and risks.
EOF
}

synth() {
  local name="$1" dir="${WORK}/$1"
  rm -rf "${dir}"
  mkdir -p \
    "${dir}/scripts/lib" \
    "${dir}/backend/cache-management" \
    "${dir}/frontend/src" \
    "${dir}/backend/application/src/main/resources/api/v1/specs" \
    "${dir}/backend/application/src/main/resources" \
    "${dir}/backend/migrations/src/main/resources/db/changelog"
  printf 'export default function App() { return null; }\n' > "${dir}/frontend/src/App.tsx"
  printf 'openapi: 3.0.3\n' \
    > "${dir}/backend/application/src/main/resources/api/v1/specs/openapi.yaml"
  printf 'spring:\n  application:\n    name: fixture\n' \
    > "${dir}/backend/application/src/main/resources/application.yml"
  printf '<configuration/>\n' \
    > "${dir}/backend/application/src/main/resources/logback-spring.xml"
  printf '<databaseChangeLog/>\n' \
    > "${dir}/backend/migrations/src/main/resources/db/changelog/db.changelog-master.xml"
  printf 'services: {}\n' > "${dir}/docker-compose.yml"
  printf 'APP_ENV=local\n' > "${dir}/.env.example"
  printf 'run = "bash scripts/replit-run.sh"\n' > "${dir}/.replit"
  cp "${REPO}/templates/generated-project/scaffold/scripts/lib/coverage-phase.sh" \
    "${dir}/scripts/lib/coverage-phase.sh"
  cat > "${dir}/backend/pom.xml" <<'EOF'
<project>
  <modules>
    <module>domain</module>
    <module>migrations</module>
    <module>observability</module>
    <module>cache-management</module>
    <module>service</module>
    <module>application</module>
  </modules>
</project>
EOF
  printf 'engineering\n' > "${dir}/.template-phase"
  write_valid_doc "${dir}"
  printf '%s' "${dir}"
}

echo "==> positive"
F="$(synth valid)"
gate_accepts "complete engineering overview" "${F}" -- run_gate "${F}"

F="$(synth mvp-draft)"
printf 'mvp\n' > "${F}/.template-phase"
printf '\n<!-- ARCHITECTURE-TODO: product context -->\n' >> "${F}/docs/architecture-overview.md"
gate_accepts "MVP overview may remain a visible draft" "${F}" -- run_gate "${F}"

F="$(synth legitimate-prose)"
printf '\n<!-- Reviewed note retained for maintainers. -->\nThe Product user group owns access requests to External systems.\n' \
  >> "${F}/docs/architecture-overview.md"
gate_accepts "ordinary prose and reviewed HTML comments are allowed" "${F}" -- run_gate "${F}"

F="$(synth no-cache-history)"
rm -rf "${F}/backend/cache-management"
sed '/<module>cache-management<\/module>/d' "${F}/backend/pom.xml" > "${F}/pom.tmp"
mv "${F}/pom.tmp" "${F}/backend/pom.xml"
sed 's/Cache status: enabled/Cache status: disabled/' \
  "${F}/docs/architecture-overview.md" > "${F}/doc.tmp"
mv "${F}/doc.tmp" "${F}/docs/architecture-overview.md"
sed '/^| `backend\/cache-management` |/d' \
  "${F}/docs/architecture-overview.md" > "${F}/doc.tmp"
mv "${F}/doc.tmp" "${F}/docs/architecture-overview.md"
printf '\n`backend/cache-management` was removed because this product does not cache data.\n' \
  >> "${F}/docs/architecture-overview.md"
gate_accepts "no-cache project may document removal history" "${F}" -- run_gate "${F}"

F="$(synth pre-handoff-telemetry)"
mkdir -p "${F}/backend/event-logging-to-db-feature"
sed 's:</modules>:    <module>event-logging-to-db-feature</module>\n  </modules>:' \
  "${F}/backend/pom.xml" > "${F}/pom.tmp"
mv "${F}/pom.tmp" "${F}/backend/pom.xml"
sed 's/MVP usage telemetry: removed/MVP usage telemetry: enabled during MVP/' \
  "${F}/docs/architecture-overview.md" > "${F}/doc.tmp"
mv "${F}/doc.tmp" "${F}/docs/architecture-overview.md"
printf '\n| `backend/event-logging-to-db-feature` | Temporary MVP feedback telemetry; removed at engineering handoff | Application service annotations and PostgreSQL during MVP only |\n' \
  >> "${F}/docs/architecture-overview.md"
gate_accepts "engineering coverage phase may precede telemetry cleanup" "${F}" -- run_gate "${F}"

echo "==> fail-closed prerequisites"
F="$(synth missing-document)"
rm "${F}/docs/architecture-overview.md"
gate_fails_closed "missing canonical document" "${F}" \
  "missing docs/architecture-overview.md" -- run_gate "${F}"

F="$(synth missing-section)"
sed '/^## Caching and consistency$/d' "${F}/docs/architecture-overview.md" > "${F}/doc.tmp"
mv "${F}/doc.tmp" "${F}/docs/architecture-overview.md"
gate_rejects "required section removed" "${F}" \
  "missing required section: Caching and consistency" -- run_gate "${F}"

echo "==> engineering finalization"
F="$(synth unresolved-marker)"
printf '\n<!-- ARCHITECTURE-TODO: unresolved -->\n' >> "${F}/docs/architecture-overview.md"
gate_rejects "unresolved handoff marker" "${F}" \
  "still contains ARCHITECTURE-TODO markers" -- run_gate "${F}"

F="$(synth unresolved-bare-product-fact)"
sed 's/Primary users: Product operations staff/Primary users: ARCHITECTURE-TODO/' \
  "${F}/docs/architecture-overview.md" > "${F}/doc.tmp"
mv "${F}/doc.tmp" "${F}/docs/architecture-overview.md"
gate_rejects "bare unresolved product fact" "${F}" \
  "still contains ARCHITECTURE-TODO markers" -- run_gate "${F}"

F="$(synth missing-lifecycle-status)"
sed '/^- Lifecycle phase:/d' "${F}/docs/architecture-overview.md" > "${F}/doc.tmp"
mv "${F}/doc.tmp" "${F}/docs/architecture-overview.md"
gate_rejects "missing engineering lifecycle status" "${F}" \
  "requires exactly one status: Lifecycle phase: Engineering" -- run_gate "${F}"

F="$(synth missing-last-verified-status)"
sed '/^- Last verified against:/d' "${F}/docs/architecture-overview.md" > "${F}/doc.tmp"
mv "${F}/doc.tmp" "${F}/docs/architecture-overview.md"
gate_rejects "missing verification revision" "${F}" \
  "requires exactly one non-empty Last verified against status" -- run_gate "${F}"

F="$(synth generic-fact)"
printf '\n- Lifecycle phase: MVP\n' >> "${F}/docs/architecture-overview.md"
gate_rejects "generic scaffold fact" "${F}" \
  "still contains generic scaffold facts" -- run_gate "${F}"

F="$(synth missing-product-fact)"
sed '/^- Primary users:/d' "${F}/docs/architecture-overview.md" > "${F}/doc.tmp"
mv "${F}/doc.tmp" "${F}/docs/architecture-overview.md"
gate_rejects "missing product-specific fact" "${F}" \
  "requires exactly one non-empty product fact: Primary users" -- run_gate "${F}"

F="$(synth duplicate-evidence)"
sed \
  's#backend/application/src/main/resources/api/v1/specs/openapi.yaml#frontend/src/App.tsx#' \
  "${F}/docs/architecture-overview.md" > "${F}/doc.tmp"
mv "${F}/doc.tmp" "${F}/docs/architecture-overview.md"
gate_rejects "duplicate implementation evidence" "${F}" \
  "requires at least two distinct implementation evidence paths" -- run_gate "${F}"

F="$(synth missing-evidence-file)"
sed 's#frontend/src/App.tsx#frontend/src/MissingProductFlow.tsx#' \
  "${F}/docs/architecture-overview.md" > "${F}/doc.tmp"
mv "${F}/doc.tmp" "${F}/docs/architecture-overview.md"
gate_rejects "missing implementation evidence file" "${F}" \
  "architecture evidence path does not exist: frontend/src/MissingProductFlow.tsx" -- run_gate "${F}"

F="$(synth product-evidence-symlink-escape)"
printf 'outside repository\n' > "${WORK}/outside-product-evidence.tsx"
ln -s "${WORK}/outside-product-evidence.tsx" "${F}/frontend/src/OutsideEvidence.tsx"
sed 's#^- Evidence path: `frontend/src/App.tsx`$#- Evidence path: `frontend/src/OutsideEvidence.tsx`#' \
  "${F}/docs/architecture-overview.md" > "${F}/doc.tmp"
mv "${F}/doc.tmp" "${F}/docs/architecture-overview.md"
gate_rejects "product evidence cannot escape through a symlink" "${F}" \
  "architecture evidence path escapes the repository through a symlink" -- run_gate "${F}"

F="$(synth missing-section-evidence)"
sed '/^- Evidence: `\.replit`$/d' "${F}/docs/architecture-overview.md" > "${F}/doc.tmp"
mv "${F}/doc.tmp" "${F}/docs/architecture-overview.md"
gate_rejects "runtime section has no implementation evidence" "${F}" \
  "section 'Runtime and deployment' requires exactly one section Evidence path line" \
  -- run_gate "${F}"

F="$(synth insufficient-distinct-section-evidence)"
sed -E 's#^- Evidence: `[^`]+`$#- Evidence: `.replit`#' \
  "${F}/docs/architecture-overview.md" > "${F}/doc.tmp"
mv "${F}/doc.tmp" "${F}/docs/architecture-overview.md"
gate_rejects "section evidence cannot collapse to one generic file" "${F}" \
  "requires at least six distinct section-evidence paths" -- run_gate "${F}"

F="$(synth section-evidence-symlink-escape)"
printf 'outside repository\n' > "${WORK}/outside-section-evidence.txt"
ln -s "${WORK}/outside-section-evidence.txt" "${F}/docs/outside-evidence.txt"
sed 's#^- Evidence: `.replit`$#- Evidence: `docs/outside-evidence.txt`#' \
  "${F}/docs/architecture-overview.md" > "${F}/doc.tmp"
mv "${F}/doc.tmp" "${F}/docs/architecture-overview.md"
gate_rejects "section evidence cannot escape through a symlink" "${F}" \
  "section evidence path escapes the repository through a symlink" -- run_gate "${F}"

F="$(synth undocumented-module)"
sed 's:</modules>:    <module>external-services</module>\n  </modules>:' \
  "${F}/backend/pom.xml" > "${F}/pom.tmp"
mv "${F}/pom.tmp" "${F}/backend/pom.xml"
gate_rejects "active reactor module omitted" "${F}" \
  "does not document active backend module: backend/external-services" -- run_gate "${F}"

F="$(synth multiline-active-module)"
sed 's:<module>application</module>:<module>application</module>\n    <module>\n      external-services\n    </module>:' \
  "${F}/backend/pom.xml" > "${F}/pom.tmp"
mv "${F}/pom.tmp" "${F}/backend/pom.xml"
gate_rejects "multiline active reactor module omitted" "${F}" \
  "does not document active backend module: backend/external-services" -- run_gate "${F}"

F="$(synth inactive-profile-module)"
sed 's:</project>:  <profiles>\n    <profile>\n      <id>optional</id>\n      <modules><module>profile-only</module></modules>\n    </profile>\n  </profiles>\n</project>:' \
  "${F}/backend/pom.xml" > "${F}/pom.tmp"
mv "${F}/pom.tmp" "${F}/backend/pom.xml"
gate_accepts "inactive profile module is not part of the active top-level reactor" \
  "${F}" -- run_gate "${F}"

F="$(synth removed-cache-claimed)"
rm -rf "${F}/backend/cache-management"
sed '/<module>cache-management<\/module>/d' "${F}/backend/pom.xml" > "${F}/pom.tmp"
mv "${F}/pom.tmp" "${F}/backend/pom.xml"
gate_rejects "removed cache still claimed" "${F}" \
  "requires exactly one architecture status: Cache status: disabled" -- run_gate "${F}"

F="$(synth mvp-telemetry-claimed)"
sed 's/MVP usage telemetry: removed/MVP usage telemetry: enabled during MVP/' \
  "${F}/docs/architecture-overview.md" > "${F}/doc.tmp"
mv "${F}/doc.tmp" "${F}/docs/architecture-overview.md"
gate_rejects "MVP telemetry claimed after handoff" "${F}" \
  "removed MVP telemetry requires exactly one architecture status: MVP usage telemetry: removed" -- run_gate "${F}"

F="$(synth inexact-active-telemetry-status)"
mkdir -p "${F}/backend/event-logging-to-db-feature"
sed 's/MVP usage telemetry: removed/MVP usage telemetry: enabled during MVP — pending handoff/' \
  "${F}/docs/architecture-overview.md" > "${F}/doc.tmp"
mv "${F}/doc.tmp" "${F}/docs/architecture-overview.md"
printf '\n| `backend/event-logging-to-db-feature` | Temporary MVP telemetry | Runtime feedback |\n' \
  >> "${F}/docs/architecture-overview.md"
gate_rejects "inexact telemetry status cannot pass preflight" "${F}" \
  "active MVP telemetry requires exactly one architecture status" -- run_gate "${F}"

gate_summary "test-gate-architecture-overview"
