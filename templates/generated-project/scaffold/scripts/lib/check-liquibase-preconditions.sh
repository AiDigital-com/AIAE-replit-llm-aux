#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# VERIFY_ROOT matches check-coverage-integrity.sh, so a fixture suite can point
# the gate at a temporary project instead of the checkout it lives in.
ROOT="${VERIFY_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

python3 "${SCRIPT_DIR}/check-liquibase-preconditions.py" \
  "${ROOT}/backend/migrations/src/main/resources/db/changelog"
