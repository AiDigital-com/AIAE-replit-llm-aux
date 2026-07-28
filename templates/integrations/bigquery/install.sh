#!/usr/bin/env bash
# Installs the BigQuery adapter into a generated project.
# Idempotent — safe to run multiple times.
#
# Depends on _http-client-foundation; installs it automatically if not present.
#
# Usage:
#   PROJECT_ROOT=/path/to/project bash templates/integrations/bigquery/install.sh
#   bash templates/integrations/bigquery/install.sh [project-root]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../_installer-lib"
HTTP_FOUNDATION_DIR="${SCRIPT_DIR}/../_http-client-foundation"

PROJECT_ROOT="${PROJECT_ROOT:-${1:-$(pwd)}}"
BACKEND_DIR="${PROJECT_ROOT}/backend"
EXT_DIR="${BACKEND_DIR}/external-services"
EXT_POM="${EXT_DIR}/pom.xml"
ENV_FILE="${PROJECT_ROOT}/.env.example"
APP_YML="${BACKEND_DIR}/application/src/main/resources/application.yml"

echo "=== Installing BigQuery pack ==="
echo "    Project root: $PROJECT_ROOT"

# ── 1. Ensure HTTP client foundation is installed (creates external-services) ──
PROJECT_ROOT="$PROJECT_ROOT" bash "${HTTP_FOUNDATION_DIR}/install.sh"

# Direct framework/logging APIs imported by this pack.
POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "org.springframework.boot" "spring-boot-autoconfigure"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "org.slf4j" "slf4j-api"

# ── 2. Add google-cloud-bigquery SDK to parent dependencyManagement ─────────
#    Version is intentionally pinned — the BOM is not pulled in by Spring Boot.
bash "${LIB_DIR}/add-managed-dependency.sh" \
    "${BACKEND_DIR}/pom.xml" \
    "com.google.cloud" \
    "google-cloud-bigquery" \
    "2.42.3"

bash "${LIB_DIR}/add-managed-dependency.sh" \
    "${BACKEND_DIR}/pom.xml" \
    "com.google.cloud" \
    "google-cloud-core" \
    "2.43.0"

bash "${LIB_DIR}/add-managed-dependency.sh" \
    "${BACKEND_DIR}/pom.xml" \
    "com.google.auth" \
    "google-auth-library-oauth2-http" \
    "1.25.0"

bash "${LIB_DIR}/add-managed-dependency.sh" \
    "${BACKEND_DIR}/pom.xml" \
    "com.google.auth" \
    "google-auth-library-credentials" \
    "1.25.0"

# ── 3. Add SDK dependency to external-services pom ─────────────────────────
POM_FILE="${EXT_DIR}/pom.xml" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "com.google.cloud" "google-cloud-bigquery"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "com.google.cloud" "google-cloud-core"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "com.google.auth" "google-auth-library-oauth2-http"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "com.google.auth" "google-auth-library-credentials"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "org.springframework" "spring-beans"

POM_FILE="${EXT_DIR}/pom.xml" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "\${project.groupId}" "event-logging-to-db-feature"

# ── 4. Copy Java source and test files ─────────────────────────────────────
bash "${LIB_DIR}/copy-pack-files.sh" \
    "${SCRIPT_DIR}/src" \
    "${EXT_DIR}/src" \
    "$PROJECT_ROOT"

# ── 5. Add environment variable placeholders ────────────────────────────────
if [ -f "$ENV_FILE" ]; then
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "BIGQUERY_ENABLED" "false"
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "BIGQUERY_STUB_ENABLED" "false"
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "BIGQUERY_CREDENTIALS_JSON" ""
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "BIGQUERY_PROJECT_ID" ""
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "BIGQUERY_DATASET" ""
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "BIGQUERY_LOCATION" "US"
fi

# ── 6. Add application.yml stubs (under existing app.external) ───────────────
if [ -f "$APP_YML" ]; then
    BQ_STUB="$(mktemp)"
    cat > "${BQ_STUB}" << 'YMLEOF'
    bigquery:
      enabled: ${BIGQUERY_ENABLED:false}
      stub-enabled: ${BIGQUERY_STUB_ENABLED:false}
      credentials-json: ${BIGQUERY_CREDENTIALS_JSON:}
      project-id: ${BIGQUERY_PROJECT_ID:}
      dataset: ${BIGQUERY_DATASET:}
      location: ${BIGQUERY_LOCATION:US}
YMLEOF
    bash "${LIB_DIR}/append-app-external-yml.sh" "$APP_YML" bigquery "${BQ_STUB}"
    rm -f "${BQ_STUB}"
fi

echo "=== BigQuery pack installed successfully ==="
