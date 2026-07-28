#!/usr/bin/env bash
# Installs the Anthropic Claude API adapter into a generated project.
# Idempotent — safe to run multiple times.
#
# Depends on _http-client-foundation; installs it automatically if not present.
#
# Usage:
#   PROJECT_ROOT=/path/to/project bash templates/integrations/claude/install.sh
#   bash templates/integrations/claude/install.sh [project-root]
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

echo "=== Installing Claude pack ==="
echo "    Project root: $PROJECT_ROOT"

# ── 1. Ensure HTTP client foundation is installed ───────────────────────────
PROJECT_ROOT="$PROJECT_ROOT" bash "${HTTP_FOUNDATION_DIR}/install.sh"

# ── 2. Add Jackson to external-services pom ─────────────────────────────────
#    Model source imports annotations directly. Databind is a runtime concern
#    used by RestClient's JSON message converter.
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
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "CLAUDE_ENABLED" "false"
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "CLAUDE_BASE_URL" "https://api.anthropic.com"
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "CLAUDE_API_KEY" ""
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "CLAUDE_API_VERSION" "2023-06-01"
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "CLAUDE_MODEL" "claude-3-5-sonnet-20241022"
    bash "${LIB_DIR}/ensure-env-placeholder.sh" "$ENV_FILE" "CLAUDE_MAX_TOKENS" "1024"
fi

# ── 5. Add application.yml stubs (under existing app.external) ───────────────
if [ -f "$APP_YML" ]; then
    CLAUDE_STUB="$(mktemp)"
    cat > "${CLAUDE_STUB}" << 'YMLEOF'
    claude:
      enabled: ${CLAUDE_ENABLED:false}
      base-url: ${CLAUDE_BASE_URL:https://api.anthropic.com}
      api-key: ${CLAUDE_API_KEY:}
      api-version: ${CLAUDE_API_VERSION:2023-06-01}
      model: ${CLAUDE_MODEL:claude-3-5-sonnet-20241022}
      max-tokens: ${CLAUDE_MAX_TOKENS:1024}
YMLEOF
    bash "${LIB_DIR}/append-app-external-yml.sh" "$APP_YML" claude "${CLAUDE_STUB}"
    rm -f "${CLAUDE_STUB}"
fi

echo "=== Claude pack installed successfully ==="
