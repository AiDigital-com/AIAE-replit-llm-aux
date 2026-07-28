#!/usr/bin/env bash
#
# structure-lint.sh — architecture checks for generated MVPs.
# Called by local-verify.sh and replit-build.sh before package/deploy.
#
# Usage (from generated project root):
#   bash scripts/structure-lint.sh
#   bash scripts/structure-lint.sh --scaffold   # template scaffold source only
#
# Root resolution: uses $PWD when it contains backend/ and is not the template
# scaffold path; otherwise uses the directory above this script. Prevents the
# footgun of linting the template scaffold while standing in a generated project directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

resolve_project_root() {
  local cwd
  cwd="$(pwd)"
  if [ -d "${cwd}/backend" ] && [ "${cwd}" != "${DEFAULT_ROOT}" ]; then
    printf '%s' "${cwd}"
  elif [ -n "${STRUCTURE_LINT_ROOT:-}" ]; then
    printf '%s' "${STRUCTURE_LINT_ROOT}"
  else
    printf '%s' "${DEFAULT_ROOT}"
  fi
}

SCAFFOLD_MODE=0
if [ "${1:-}" = "--scaffold" ]; then
  SCAFFOLD_MODE=1
fi

ROOT="$(resolve_project_root)"
cd "${ROOT}"

if [ -f backend/pom.xml ]; then
  group_id="$(sed -n 's:.*<groupId>\(.*\)</groupId>.*:\1:p' backend/pom.xml | head -n 1)"
  if [ "${group_id}" = "PACKAGE_REPLACE_ME" ] && [[ "${ROOT}" == */templates/generated-project/scaffold ]]; then
    SCAFFOLD_MODE=1
  fi
fi

fail() {
  echo "structure-lint: $*" >&2
  exit 1
}

[ -d backend ] || exit 0

echo "==> structure-lint root=${ROOT} scaffold_mode=${SCAFFOLD_MODE}"

# --- Canonical backend scaffold shape ---
[ ! -d backend/src/main/java ] \
  || fail "backend/src/main/java is forbidden — use backend/application, backend/service, backend/domain, and backend/migrations modules"

[ ! -d backend/src/main/resources ] \
  || fail "backend/src/main/resources is forbidden — module resources belong under backend/application/src/main/resources or backend/migrations/src/main/resources"

[ ! -f Dockerfile ] \
  || fail "root Dockerfile is forbidden — use backend/Dockerfile and frontend/Dockerfile"

[ -f backend/pom.xml ] \
  || fail "backend/pom.xml missing — copy canonical backend scaffold"

grep -q '<packaging>pom</packaging>' backend/pom.xml \
  || fail "backend/pom.xml must be a Maven parent POM with <packaging>pom</packaging>"

for module in application service domain migrations observability; do
  [ -d "backend/${module}" ] \
    || fail "backend/${module}/ missing — copy canonical backend scaffold"
  [ -f "backend/${module}/pom.xml" ] \
    || fail "backend/${module}/pom.xml missing — copy canonical backend scaffold"
  grep -q "<module>${module}</module>" backend/pom.xml \
    || fail "backend/pom.xml must list required module: ${module}"
done

# --- Optional feature consistency: usage logging ---
if [ -d backend/event-logging-to-db-feature ]; then
  [ -f backend/event-logging-to-db-feature/pom.xml ] \
    || fail "event-logging-to-db-feature/pom.xml is missing"
  grep -q '<module>event-logging-to-db-feature</module>' backend/pom.xml \
    || fail "parent POM must list the present event-logging module"
  grep -q '<artifactId>event-logging-to-db-feature</artifactId>' backend/service/pom.xml \
    || fail "service/pom.xml must attach the present event-logging module"
  [ -f backend/migrations/src/main/resources/db/changelog/changes/0001-usage-events.xml ] \
    || fail "present event-logging module requires the usage-events migration"
else
  ! grep -q '<module>event-logging-to-db-feature</module>' backend/pom.xml \
    || fail "parent POM lists an absent event-logging module"
  ! grep -Rqs '<artifactId>event-logging-to-db-feature</artifactId>' backend/*/pom.xml \
    || fail "a POM depends on the absent event-logging module"
  [ ! -f backend/migrations/src/main/resources/db/changelog/changes/0001-usage-events.xml ] \
    || fail "usage-events migration remains without the event-logging module"
fi

# --- Optional feature consistency: L2 + multi-node invalidation ---
if [ -d backend/cache-management ]; then
  [ -f backend/cache-management/pom.xml ] \
    || fail "cache-management/pom.xml is missing"
  grep -q '<module>cache-management</module>' backend/pom.xml \
    || fail "parent POM must list the present cache-management module"
  grep -q '<artifactId>cache-management</artifactId>' backend/service/pom.xml \
    || fail "service/pom.xml must attach the cache-management runtime module"
  grep -Rqs '@EnableScheduling' backend/application/src/main/java \
    || fail "application must enable scheduling for cache invalidation polling"
  find backend/service/src/main/java -name 'JpaCacheInvalidationEventService.java' -print -quit \
    | grep -q . \
    || fail "JPA cache invalidation outbox service is missing"
  find backend/service/src/main/java -name 'ApplicationCacheNamesByClassRegistry.java' -print -quit \
    | grep -q . \
    || fail "application-owned cache region registry is missing"
  [ -f backend/migrations/src/main/resources/db/changelog/changes/0003-cache-invalidation.xml ] \
    || fail "cache invalidation Liquibase migration is missing"
  grep -q '0003-cache-invalidation.xml' \
    backend/migrations/src/main/resources/db/changelog/db.changelog-master.xml \
    || fail "master changelog must include the cache invalidation migration"
  if grep -Rqs 'updatesAfter(LocalDateTime' backend/cache-management/src/main/java; then
    fail "timestamp cache invalidation cursors are forbidden — poll by monotonic event ID"
  fi
  if grep -Rqs 'parallelStream()' backend/application/src/main/java/*/cache 2>/dev/null; then
    fail "parallel cache warm-up is forbidden — use sequential or explicitly bounded loading"
  fi
else
  ! grep -q '<module>cache-management</module>' backend/pom.xml \
    || fail "parent POM lists an absent cache-management module"
  ! grep -Rqs '<artifactId>cache-management</artifactId>' backend/*/pom.xml \
    || fail "a POM depends on the absent cache-management module"
  [ ! -f backend/migrations/src/main/resources/db/changelog/changes/0003-cache-invalidation.xml ] \
    || fail "cache invalidation migration remains without cache-management"
  [ ! -f backend/application/src/main/resources/ehcache.xml ] \
    || fail "ehcache.xml remains without cache-management"
fi

# --- Reusable external-client metrics boundary ---
grep -q '<artifactId>observability</artifactId>' backend/application/pom.xml \
  || fail "application/pom.xml must attach the reusable external metrics module"
for app_owned in LogbookConfig CorrelationIdFilter; do
  find backend/application/src/main/java -name "${app_owned}.java" -print -quit | grep -q . \
    || fail "${app_owned} must remain application-owned"
done
[ -f backend/application/src/main/resources/logback-spring.xml ] \
  || fail "application must own src/main/resources/logback-spring.xml"
for reusable_metric in ExternalClientMetricsInterceptor ExternalCallTimer; do
  find backend/observability/src/main/java -name "${reusable_metric}.java" -print -quit | grep -q . \
    || fail "observability must own ${reusable_metric}"
done
if grep -RIlE 'class[[:space:]]+(ExternalClientMetricsInterceptor|ExternalCallTimer)\b' \
    backend/application/src/main/java backend/service/src/main/java \
    backend/domain/src/main/java backend/external-services/src/main/java \
    2>/dev/null | grep -q .; then
  fail "ExternalClientMetricsInterceptor and ExternalCallTimer belong only in backend/observability"
fi
if grep -Eq '<artifactId>(application|service|domain|migrations|external-services)</artifactId>' \
    backend/observability/pom.xml; then
  fail "observability must remain reusable and must not depend on application/service/domain/migrations/external-services"
fi

# Every backend Maven submodule declares the parent-managed Lombok dependency,
# including resource-only and optional modules.
for module in $(sed -n 's:.*<module>\(.*\)</module>.*:\1:p' backend/pom.xml); do
  grep -q '<artifactId>lombok</artifactId>' "backend/${module}/pom.xml" \
    || fail "backend/${module}/pom.xml must declare Lombok"
done

# --- Package namespace (generated apps only) ---
if [ "${SCAFFOLD_MODE}" -eq 0 ] && [ -f backend/pom.xml ]; then
  group_id="$(sed -n 's:.*<groupId>\(.*\)</groupId>.*:\1:p' backend/pom.xml | head -n 1)"
  [[ "${group_id}" =~ ^com\.aidigital\.[a-z][a-z0-9]*$ ]] \
    || fail "backend/pom.xml groupId must be com.aidigital.<app-name-package>: got ${group_id}"
  if grep -RInE '^package[[:space:]]+' \
      backend/application/src/main/java backend/service/src/main/java backend/domain/src/main/java 2>/dev/null \
      | grep -Ev '^.*:package[[:space:]]+com\.aidigital\.' | grep -q .; then
    fail "Java packages must start with com.aidigital.<app-name-package>"
  fi
fi

# --- Clerk-only auth ---
if grep -RInE 'MockJwtDecoder|MockTokenService|ReplitOidcSecurityConfig|AUTH_MODE|/auth/mock/login' \
    backend frontend/src 2>/dev/null | grep -v '/target/' | grep -q .; then
  fail "Clerk SSO only — remove mock/Replit OIDC auth (MockJwtDecoder, AUTH_MODE, etc.)"
fi

# --- Sample aggregate must not ship in generated apps ---
# STRUCTURE_LINT_ALLOW_SAMPLE=1 — ci-verify-scaffold materializes a compilable
# project with reference samples still present (strip happens at publish time).
if [ "${SCAFFOLD_MODE}" -eq 0 ] && [ "${STRUCTURE_LINT_ALLOW_SAMPLE:-0}" -ne 1 ]; then
  find backend/domain/src/main/java -type d -path '*/domain/sample' 2>/dev/null | grep -q . \
    && fail "domain/sample/ still present — run bash scripts/strip-scaffold-samples.sh"
  find backend/service/src/main/java -type d -path '*/service/sample' 2>/dev/null | grep -q . \
    && fail "service/sample/ still present — run bash scripts/strip-scaffold-samples.sh"
  master="backend/migrations/src/main/resources/db/changelog/db.changelog-master.xml"
  if [ -f "${master}" ] && grep -q '0002-sample-reference.xml' "${master}"; then
    fail "db.changelog-master.xml still includes 0002-sample-reference.xml — run strip-scaffold-samples.sh"
  fi
fi

# --- Controllers live under */controllers/ (SpaFallbackController under web/ is OK) ---
while IFS= read -r ctrl; do
  fail "Controller outside controllers/ or web/: ${ctrl}"
done < <(find backend/application/src/main/java -name '*Controller.java' \
  ! -path '*/controllers/*' ! -path '*/web/*' 2>/dev/null)

# --- OpenAPI contract: no ad-hoc HTTP mapping on API controllers ---
if [ -d backend/application/src/main/java ]; then
  if grep -RInE '@(RequestMapping|GetMapping|PostMapping|PutMapping|PatchMapping|DeleteMapping)\b' \
      backend/application/src/main/java 2>/dev/null \
      | grep '/controllers/' | grep -q .; then
    fail "API controllers must implement generated *Api interfaces — remove @RequestMapping/@GetMapping"
  fi
fi

# --- Thin controllers: no repositories ---
if grep -rEn 'private final.*Repository' backend/application/src/main/java 2>/dev/null \
    | grep '/controllers/' | grep -q .; then
  fail "Controllers must not inject repositories — delegate to *Service"
fi

if grep -RInE 'new[[:space:]]+[A-Za-z0-9_]+V[0-9]+[[:space:]]*\(' \
    backend/application/src/main/java 2>/dev/null | grep '/controllers/' | grep -q .; then
  fail "Controllers must not manually construct generated *V1 DTOs — delegate DTO construction to API mappers"
fi

# API controllers are generated-OpenAPI delegation boundaries. Keep the
# infrastructure web package out of this check: SpaFallbackController has
# HTTP-specific routing behavior and is intentionally not an API controller.
if [ -f "${SCRIPT_DIR}/lib/check-thin-controllers.py" ]; then
  python3 "${SCRIPT_DIR}/lib/check-thin-controllers.py" backend/application/src/main/java
fi


# --- MapStruct mapper ownership: one aggregate/entity = one mapper ---
if [ -d backend/application/src/main/java ]; then
  if find backend/application/src/main/java -path '*/mappers/ApiDtoMapper.java' -o \
      -path '*/mappers/DtoMapper.java' -o \
      -path '*/mappers/ApplicationMapper.java' -o \
      -path '*/mappers/CommonMapper.java' 2>/dev/null | grep -q .; then
    fail "Global API mapper is forbidden — create one mappers/<aggregate>/<Aggregate>ApiMapper per aggregate and compose with MapStruct uses="
  fi
  if grep -RInE '\bApiDtoMapper\b|\bDtoMapper\b|\bApplicationMapper\b|\bCommonMapper\b' \
      backend/application/src/main/java 2>/dev/null | grep -v 'ApplicationMapperConfig' | grep -q .; then
    fail "Controllers/application code must not inject/use generic ApiDtoMapper/DtoMapper; use mappers/<aggregate>/*ApiMapper"
  fi
  if find backend/application/src/main/java -path '*/mappers/*ListSource.java' -o \
      -path '*/mappers/*ResponseSource.java' -o \
      -path '*/mappers/*MapperSource.java' 2>/dev/null | grep -q .; then
    fail "Application mapper source wrapper records (*ListSource/*ResponseSource) are forbidden — return List<T> for simple lists and map the list parameter directly"
  fi
  while IFS= read -r mapper_file; do
    rel="${mapper_file#backend/application/src/main/java/}"
    if [[ ! "${rel}" =~ ^([^/]+/){3}mappers/[^/]+/[^/]+ApiMapper\.java$ ]] \
        && [[ ! "${rel}" =~ ^([^/]+/){3}mappers/auth/UserMapper\.java$ ]] \
        && [[ ! "${rel}" =~ ^PACKAGE_REPLACE_ME/mappers/[^/]+/[^/]+Mapper\.java$ ]]; then
      fail "Application API mapper must live under mappers/<aggregate>/, not aggregate/mappers or root mappers/: ${mapper_file}"
    fi
    grep -q '@Mapper' "${mapper_file}" \
      || fail "Application mapper must be a MapStruct @Mapper interface: ${mapper_file}"
    grep -Eq 'public[[:space:]]+interface[[:space:]]+[A-Za-z0-9_]+Mapper\b' "${mapper_file}" \
      || fail "Application mapper must be an interface, not a hand-written class: ${mapper_file}"
    ! grep -q '^[[:space:]]*default[[:space:]].*Map<String,[[:space:]]*Object>' "${mapper_file}" \
      || fail "Application mapper must not hide manual Map<String,Object> mapping in default methods: ${mapper_file}"
    ! grep -Eq 'new[[:space:]]+[A-Za-z0-9]+V[0-9]+[[:space:]]*\(' "${mapper_file}" \
      || fail "Application mapper must let MapStruct construct generated DTOs; remove manual new *V1(): ${mapper_file}"
    ! grep -q 'ApiMappingSupport' "${mapper_file}" \
      || fail "Application mapper must not use generic ApiMappingSupport coercions; fix typed service records: ${mapper_file}"
    ! grep -Eq 'new[[:space:]]+[A-Za-z0-9_]*(List|Response|Mapper)?Source[[:space:]]*\(' "${mapper_file}" \
      || fail "Application mapper must not create artificial *Source wrapper records; fix typed service records: ${mapper_file}"
  done < <(find backend/application/src/main/java -path '*/mappers/*Mapper.java' ! -name 'ApplicationMapperConfig.java' 2>/dev/null)
fi

if [ -d backend/service/src/main/java ]; then
  if grep -RInE 'Map<String,[[:space:]]*Object>|List<Map<String,[[:space:]]*Object>>' \
      backend/service/src/main/java --include='*Service.java' 2>/dev/null | grep -q .; then
    fail "Service interfaces must not expose Map<String,Object>; create typed records and isolate JSON/provider maps at boundary converters"
  fi
  if grep -RInE 'public[[:space:]]+record[[:space:]]+[A-Za-z0-9_]+ListRecord[[:space:]]*\([[:space:]]*List<[^>]+>[[:space:]]+[A-Za-z0-9_]+[[:space:]]*\)' \
      backend/service/src/main/java --include='*ListRecord.java' 2>/dev/null | grep -q .; then
    fail "One-field service *ListRecord wrappers are forbidden — return List<T> directly for simple list use cases"
  fi
  if find backend/service/src/main/java -path '*/mappers/DtoMapper.java' -o \
      -path '*/mappers/EntityMapper.java' -o \
      -path '*/mappers/CommonMapper.java' 2>/dev/null | grep -q .; then
    fail "Generic service mapper is forbidden — create one service/mappers/<aggregate>/<Entity>Mapper per entity and compose with MapStruct uses="
  fi
  while IFS= read -r mapper_file; do
    rel="${mapper_file#backend/service/src/main/java/}"
    if [[ ! "${rel}" =~ ^([^/]+/){3}service/mappers/[^/]+/[^/]+Mapper\.java$ ]] \
        && [[ ! "${rel}" =~ ^PACKAGE_REPLACE_ME/service/mappers/[^/]+/[^/]+Mapper\.java$ ]]; then
      fail "Service mapper must live under service/mappers/<aggregate>/, not service/<aggregate>/mappers/: ${mapper_file}"
    fi
    grep -q '@Mapper' "${mapper_file}" \
      || fail "Service mapper must be a MapStruct @Mapper interface: ${mapper_file}"
    grep -Eq 'public[[:space:]]+interface[[:space:]]+[A-Za-z0-9_]+Mapper\b' "${mapper_file}" \
      || fail "Service mapper must be an interface, not a hand-written class: ${mapper_file}"
  done < <(find backend/service/src/main/java -path '*/mappers/*Mapper.java' ! -name 'ServiceMapperConfig.java' 2>/dev/null)
fi

# --- No @Service orchestration in application/ ---
if grep -rEn '^@Service' backend/application/src/main/java 2>/dev/null | grep -q .; then
  fail "@Service beans belong in service/, not application/"
fi

# --- Module edges when external-services exists ---
if [ -f backend/external-services/pom.xml ]; then
  grep -q '<artifactId>external-services</artifactId>' backend/application/pom.xml 2>/dev/null \
    && fail "application/pom.xml must not depend on external-services — route through service/"
  [ -f backend/service/pom.xml ] \
    && grep -q '<artifactId>external-services</artifactId>' backend/service/pom.xml \
    || fail "service/pom.xml must depend on external-services when that module exists"
  pooled_factory="$(find backend/external-services/src/main/java -name 'PooledRestClientFactory.java' -print -quit 2>/dev/null)"
  if [ -n "${pooled_factory}" ]; then
    grep -Fq 'new ExternalClientMetricsInterceptor(name, meterRegistry)' "${pooled_factory}" \
      || fail "PooledRestClientFactory must register ExternalClientMetricsInterceptor"
    grep -Fq 'new LogbookClientHttpRequestInterceptor(logbook)' "${pooled_factory}" \
      || fail "PooledRestClientFactory must register LogbookClientHttpRequestInterceptor"
  fi
  while IFS= read -r direct_client; do
    [ "$(basename "${direct_client}")" = "PooledRestClientFactory.java" ] \
      || fail "Third-party Spring HTTP clients must use PooledRestClientFactory: ${direct_client}"
  done < <(grep -RIlE 'RestClient\.(builder|create)|new[[:space:]]+RestTemplate|WebClient\.builder' \
    backend/external-services/src/main/java 2>/dev/null || true)
fi

# --- Every *Controller (except web/) should implement a generated *Api ---
while IFS= read -r ctrl; do
  base="$(basename "${ctrl}" .java)"
  grep -q 'implements .*Api' "${ctrl}" \
    || fail "${base} must implement a generated OpenAPI *Api interface"
done < <(find backend/application/src/main/java -path '*/controllers/*Controller.java' 2>/dev/null)

spa_fallback="$(find backend/application/src/main/java -path '*/web/SpaFallbackController.java' -print -quit 2>/dev/null)"
[ -n "${spa_fallback}" ] || fail "SpaFallbackController required for deployment deep links"

# --- Frontend app shell ---
if [ -d frontend/src ]; then
  [ -f frontend/src/app/AppRoot.tsx ] \
    || fail "frontend/src/app/AppRoot.tsx missing — router + auth live here, not main.tsx"
  [ -f frontend/src/app/AppShell.tsx ] \
    || fail "frontend/src/app/AppShell.tsx missing — top-header layout shell"
  grep -q 'AuthProvider' frontend/src/app/AppRoot.tsx \
    || fail "AppRoot.tsx must mount AuthProvider (never ClerkProvider directly in main.tsx)"
  grep -q 'ProtectedRoute' frontend/src/app/AppRoot.tsx \
    || fail "AppRoot.tsx must wrap authenticated routes with ProtectedRoute"
  grep -q 'BrowserRouter' frontend/src/app/AppRoot.tsx \
    || fail "AppRoot.tsx must use BrowserRouter; HashRouter and ad-hoc history routing are forbidden"
  if grep -q 'ClerkProvider' frontend/src/main.tsx 2>/dev/null; then
    fail "main.tsx must not mount ClerkProvider — use app/AppRoot.tsx + shared/auth/AuthProvider"
  fi
  [ -f frontend/src/shared/hooks/useDebounce.ts ] \
    || fail "frontend/src/shared/hooks/useDebounce.ts missing"
  template_phase="mvp"
  if [ -f .template-phase ]; then
    template_phase="$(tr -d '[:space:]' < .template-phase)"
  fi
  if [ ! -d frontend/src/features/_template ] && [ "${template_phase}" != "engineering" ]; then
    fail "frontend/src/features/_template/ missing during MVP phase — copy for new features"
  fi
fi

echo "==> structure-lint: passed"
