#!/usr/bin/env bash
# Installs the Google Workspace adapter pack into a generated project.
# Idempotent — safe to run multiple times.
#
# Depends on _http-client-foundation; installs it automatically if not present.
#
# Usage:
#   PROJECT_ROOT=/path/to/project bash templates/integrations/google-workspace/install.sh
#   bash templates/integrations/google-workspace/install.sh [project-root]
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

echo "=== Installing Google Workspace pack ==="
echo "    Project root: $PROJECT_ROOT"

# ── 1. Ensure HTTP client foundation is installed ───────────────────────────
PROJECT_ROOT="$PROJECT_ROOT" bash "${HTTP_FOUNDATION_DIR}/install.sh"

# Direct framework/logging APIs imported by this pack.
POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "org.springframework.boot" "spring-boot-autoconfigure"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "org.slf4j" "slf4j-api"

# ── 2. Add Google API Client Library dependencies to parent dependencyManagement ──
#    Versions are pinned — Spring Boot BOM does not manage these.
bash "${LIB_DIR}/add-managed-dependency.sh" \
    "${BACKEND_DIR}/pom.xml" \
    "com.google.apis" "google-api-services-docs" "v1-rev20260427-2.0.0"

bash "${LIB_DIR}/add-managed-dependency.sh" \
    "${BACKEND_DIR}/pom.xml" \
    "com.google.apis" "google-api-services-drive" "v3-rev20240521-2.0.0"

bash "${LIB_DIR}/add-managed-dependency.sh" \
    "${BACKEND_DIR}/pom.xml" \
    "com.google.apis" "google-api-services-sheets" "v4-rev20240319-2.0.0"

bash "${LIB_DIR}/add-managed-dependency.sh" \
    "${BACKEND_DIR}/pom.xml" \
    "com.google.apis" "google-api-services-slides" "v1-rev20240305-2.0.0"

bash "${LIB_DIR}/add-managed-dependency.sh" \
    "${BACKEND_DIR}/pom.xml" \
    "com.google.auth" "google-auth-library-oauth2-http" "1.23.0"

bash "${LIB_DIR}/add-managed-dependency.sh" \
    "${BACKEND_DIR}/pom.xml" \
    "com.google.auth" "google-auth-library-credentials" "1.23.0"

bash "${LIB_DIR}/add-managed-dependency.sh" \
    "${BACKEND_DIR}/pom.xml" \
    "com.google.api-client" "google-api-client" "2.7.2"

bash "${LIB_DIR}/add-managed-dependency.sh" \
    "${BACKEND_DIR}/pom.xml" \
    "com.google.http-client" "google-http-client" "1.44.1"

bash "${LIB_DIR}/add-managed-dependency.sh" \
    "${BACKEND_DIR}/pom.xml" \
    "com.google.http-client" "google-http-client-gson" "1.44.1"

# ── 3. Add SDK dependencies to external-services pom ───────────────────────
EXT_POM="${EXT_DIR}/pom.xml"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "com.google.apis" "google-api-services-docs"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "com.google.apis" "google-api-services-drive"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "com.google.apis" "google-api-services-sheets"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "com.google.apis" "google-api-services-slides"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "com.google.auth" "google-auth-library-oauth2-http"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "com.google.auth" "google-auth-library-credentials"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "com.google.api-client" "google-api-client"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "com.google.http-client" "google-http-client"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "com.google.http-client" "google-http-client-gson"

# ── 4. Copy Java source and test files ─────────────────────────────────────
bash "${LIB_DIR}/copy-pack-files.sh" \
    "${SCRIPT_DIR}/src" \
    "${EXT_DIR}/src" \
    "$PROJECT_ROOT"

# ── 5. Add environment variable placeholders ────────────────────────────────
if [ -f "$ENV_FILE" ]; then
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "GOOGLE_WORKSPACE_CREDENTIALS_JSON" ""
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "GOOGLE_WORKSPACE_STUB_ENABLED" "false"
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "GOOGLE_WORKSPACE_DOCS_ENABLED" "false"
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "GOOGLE_WORKSPACE_DRIVE_ENABLED" "false"
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "GOOGLE_WORKSPACE_SHEETS_ENABLED" "false"
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "GOOGLE_WORKSPACE_SLIDES_ENABLED" "false"
fi

# ── 6. Add application.yml stubs (under existing app.external) ─────────────
if [ -f "$APP_YML" ]; then
    GW_STUB="$(mktemp)"
    cat > "${GW_STUB}" << 'YMLEOF'
    google-workspace:
      credentials-json: ${GOOGLE_WORKSPACE_CREDENTIALS_JSON:}
      stub-enabled: ${GOOGLE_WORKSPACE_STUB_ENABLED:false}
      docs-enabled: ${GOOGLE_WORKSPACE_DOCS_ENABLED:false}
      drive-enabled: ${GOOGLE_WORKSPACE_DRIVE_ENABLED:false}
      sheets-enabled: ${GOOGLE_WORKSPACE_SHEETS_ENABLED:false}
      slides-enabled: ${GOOGLE_WORKSPACE_SLIDES_ENABLED:false}
YMLEOF
    bash "${LIB_DIR}/append-app-external-yml.sh" "$APP_YML" google-workspace "${GW_STUB}"
    rm -f "${GW_STUB}"
fi

echo "=== Google Workspace pack installed successfully ==="
