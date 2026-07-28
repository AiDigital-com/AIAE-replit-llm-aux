#!/usr/bin/env bash
#
# check-production-current-time.sh — rejects direct now() calls in business code.
#
# Use the injectable service/common/time/CurrentTime bean instead. By default
# scans generated app-owned modules only; self-contained template feature modules
# keep their own internal time handling.
#
# Usage:
#   bash scripts/lib/check-production-current-time.sh [src_root...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCAFFOLD_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

shopt -s nullglob
if [ $# -eq 0 ]; then
  cd "${SCAFFOLD_ROOT}"
  roots=()
  for module in application service domain external-services; do
    [ -d "backend/${module}/src/main/java" ] && roots+=("backend/${module}/src/main/java")
  done
  # Empty when the project has no Java source tree yet; bash 3.2 errors on a bare
  # "${arr[@]}" for an empty array under set -u.
  set -- ${roots[@]+"${roots[@]}"}
else
  cd "${PROJECT_ROOT:-$(pwd)}"
fi
if [ $# -eq 0 ]; then
  echo "check-production-current-time: no source directories to scan"
  exit 0
fi

exec python3 "${SCRIPT_DIR}/scan-production-java.py" time "$@"
