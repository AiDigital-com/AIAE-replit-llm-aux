#!/usr/bin/env bash
# Idempotently adds a VAR= line to .env.example.
# Usage: ensure-env-placeholder.sh <env-file> <VAR_NAME> [default-value]
set -euo pipefail

ENV_FILE="${1:?Usage: ensure-env-placeholder.sh <env-file> <VAR_NAME> [default-value]}"
VAR_NAME="${2:?Usage: ensure-env-placeholder.sh <env-file> <VAR_NAME> [default-value]}"
DEFAULT_VALUE="${3:-}"

if [ ! -f "$ENV_FILE" ]; then
    echo "[ensure-env-placeholder] ERROR: $ENV_FILE not found" >&2
    exit 1
fi

# Check if VAR_NAME already present (any assignment form: VAR= or VAR=value or #VAR=...).
if grep -qE "^#?${VAR_NAME}=" "$ENV_FILE" 2>/dev/null; then
    echo "[ensure-env-placeholder] $VAR_NAME already present in $ENV_FILE — skipping"
    exit 0
fi

# Append the placeholder.
printf '\n%s=%s\n' "$VAR_NAME" "$DEFAULT_VALUE" >> "$ENV_FILE"
echo "[ensure-env-placeholder] Added $VAR_NAME to $ENV_FILE"
