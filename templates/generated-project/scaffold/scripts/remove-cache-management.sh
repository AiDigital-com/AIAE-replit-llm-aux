#!/usr/bin/env bash
#
# Remove the complete cache stack from a generated project that does not cache
# application data. This removes L2/JCache and cross-node invalidation together;
# partial states are intentionally unsupported.
#
# Usage:
#   bash scripts/remove-cache-management.sh          # validated dry run
#   bash scripts/remove-cache-management.sh --apply  # perform removal

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

exec python3 "${SCRIPT_DIR}/lib/remove-cache-management.py" "${PROJECT_ROOT}" "$@"
