#!/usr/bin/env bash
# Installs the OpenAI adapter (Responses API default; Chat Completions legacy).
# Idempotent — safe to run multiple times.
#
# Depends on _http-client-foundation; installs it automatically if not present.
#
# Usage:
#   PROJECT_ROOT=/path/to/project bash templates/integrations/openai/install.sh
#   bash templates/integrations/openai/install.sh [project-root]
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

echo "=== Installing OpenAI pack ==="
echo "    Project root: $PROJECT_ROOT"

# ── 1. Ensure HTTP client foundation is installed ───────────────────────────
PROJECT_ROOT="$PROJECT_ROOT" bash "${HTTP_FOUNDATION_DIR}/install.sh"

# ── 2. Add Jackson to external-services pom (if not already present) ────────
#    Model source imports annotations directly. Databind is retained at runtime
#    for RestClient JSON serialization/deserialization.
POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "org.springframework.boot" "spring-boot-autoconfigure"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "org.slf4j" "slf4j-api"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "com.fasterxml.jackson.core" "jackson-annotations"

POM_FILE="$EXT_POM" bash "${LIB_DIR}/add-service-dependency.sh" "$PROJECT_ROOT" \
    "com.fasterxml.jackson.core" "jackson-databind" "" "runtime"

# ── 3. Copy Java source and test files ─────────────────────────────────────
bash "${LIB_DIR}/copy-pack-files.sh" \
    "${SCRIPT_DIR}/src" \
    "${EXT_DIR}/src" \
    "$PROJECT_ROOT"

# ── 4. Add environment variable placeholders ────────────────────────────────
if [ -f "$ENV_FILE" ]; then
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "OPENAI_ENABLED" "false"
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "OPENAI_BASE_URL" "https://api.openai.com"
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "OPENAI_API_KEY" ""
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "OPENAI_MODEL" "gpt-4o"
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "OPENAI_MAX_TOKENS" "1024"
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "OPENAI_API_MODE" "responses"
fi

# ── 5. Add application.yml stubs (under existing app.external) ───────────────
if [ -f "$APP_YML" ]; then
    OPENAI_STUB="$(mktemp)"
    cat > "${OPENAI_STUB}" << 'YMLEOF'
    openai:
      enabled: ${OPENAI_ENABLED:false}
      base-url: ${OPENAI_BASE_URL:https://api.openai.com}
      api-key: ${OPENAI_API_KEY:}
      api-mode: ${OPENAI_API_MODE:responses}
      model: ${OPENAI_MODEL:gpt-4o}
      max-tokens: ${OPENAI_MAX_TOKENS:1024}
YMLEOF
    bash "${LIB_DIR}/append-app-external-yml.sh" "$APP_YML" openai "${OPENAI_STUB}"
    rm -f "${OPENAI_STUB}"
fi

echo "=== OpenAI pack installed successfully ==="
