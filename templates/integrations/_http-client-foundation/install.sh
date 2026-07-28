#!/usr/bin/env bash
# Installs the shared HTTP client foundation into a generated project.
# Idempotent — safe to run multiple times.
#
# Usage:
#   PROJECT_ROOT=/path/to/project bash templates/integrations/_http-client-foundation/install.sh
#   bash templates/integrations/_http-client-foundation/install.sh [project-root]
#
# Defaults PROJECT_ROOT to the current working directory when not set.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../_installer-lib"

PROJECT_ROOT="${PROJECT_ROOT:-${1:-$(pwd)}}"
BACKEND_DIR="${PROJECT_ROOT}/backend"
EXT_DIR="${BACKEND_DIR}/external-services"
EXT_POM="${EXT_DIR}/pom.xml"
ENV_FILE="${PROJECT_ROOT}/.env.example"
APP_YML="${BACKEND_DIR}/application/src/main/resources/application.yml"

echo "=== Installing HTTP client foundation ==="
echo "    Project root: $PROJECT_ROOT"

# ── 1. Create external-services Maven module ────────────────────────────────
bash "${LIB_DIR}/install-external-services-module.sh" "$PROJECT_ROOT"

# ── 2. Runtime/test dependencies on external-services only (Spring Boot BOM) ──
# Do not add versionless entries to parent dependencyManagement — that overrides
# inherited Spring Boot dependency management and breaks the reactor POM.
POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "org.apache.httpcomponents.client5" "httpclient5"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "org.apache.httpcomponents.core5" "httpcore5"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "org.springframework" "spring-web"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "org.springframework" "spring-context"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "org.springframework.boot" "spring-boot"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "jakarta.annotation" "jakarta.annotation-api"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "jakarta.validation" "jakarta.validation-api"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "io.micrometer" "micrometer-core"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "org.zalando" "logbook-api" "\${logbook.version}"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "org.zalando" "logbook-spring" "\${logbook.version}"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "com.squareup.okhttp3" "mockwebserver" "4.12.0" "test"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "com.squareup.okhttp3" "okhttp" "4.12.0" "test"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "com.squareup.okio" "okio-jvm" "3.6.0" "test"

# ── 3. Add the adapter module to the application runtime assembly ────────────
# The generated service module does not use an integration until product code
# explicitly calls it, so adding a compile edge there would be an unused
# dependency. Application owns runtime assembly and component discovery.
POM_FILE="${BACKEND_DIR}/application/pom.xml" \
  bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "\${project.groupId}" "external-services" "" "runtime"

# ── 4. Copy Java source and test files ─────────────────────────────────────
DEST_EXT="${EXT_DIR}/src"
bash "${LIB_DIR}/copy-pack-files.sh" \
    "${SCRIPT_DIR}/src" \
    "$DEST_EXT" \
    "$PROJECT_ROOT"

# ── 5. Add environment variable placeholders ────────────────────────────────
if [ -f "$ENV_FILE" ]; then
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "APP_EXTERNAL_HTTP_MAX_TOTAL_CONNECTIONS" "50"
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "APP_EXTERNAL_HTTP_MAX_CONNECTIONS_PER_ROUTE" "10"
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "APP_EXTERNAL_HTTP_CONNECT_TIMEOUT" "5s"
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "APP_EXTERNAL_HTTP_RESPONSE_TIMEOUT" "30s"
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "APP_EXTERNAL_HTTP_CONNECTION_REQUEST_TIMEOUT" "5s"
fi

# ── 6. Add application.yml stubs (under existing app:, not a duplicate root key) ─
if [ -f "$APP_YML" ]; then
    HTTP_STUB="$(mktemp)"
    cat > "${HTTP_STUB}" << 'YMLEOF'
    http:
      connect-timeout: ${APP_EXTERNAL_HTTP_CONNECT_TIMEOUT:5s}
      response-timeout: ${APP_EXTERNAL_HTTP_RESPONSE_TIMEOUT:30s}
      connection-request-timeout: ${APP_EXTERNAL_HTTP_CONNECTION_REQUEST_TIMEOUT:5s}
      max-total-connections: ${APP_EXTERNAL_HTTP_MAX_TOTAL_CONNECTIONS:50}
      max-connections-per-route: ${APP_EXTERNAL_HTTP_MAX_CONNECTIONS_PER_ROUTE:10}
      keep-alive-duration: 60s
      idle-eviction-duration: 30s
YMLEOF
    bash "${LIB_DIR}/append-app-external-yml.sh" "$APP_YML" http "${HTTP_STUB}"
    rm -f "${HTTP_STUB}"
fi

echo "=== HTTP client foundation installed successfully ==="
