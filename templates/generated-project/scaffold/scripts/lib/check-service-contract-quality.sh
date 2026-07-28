#!/usr/bin/env bash
# Rejects undocumented service interfaces and oversized ServiceImpl classes.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
python3 "${SCRIPT_DIR}/check-service-contract-quality.py" "$@"
