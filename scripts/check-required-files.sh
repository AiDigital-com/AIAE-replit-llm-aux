#!/usr/bin/env bash
# Verify the small set of entry points that define the template contract.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIST="${ROOT}/tests/template-required-files.txt"

[ -f "$LIST" ] || {
  echo "check-required-files: missing tests/template-required-files.txt" >&2
  exit 1
}

failures=0
while IFS= read -r path; do
  case "$path" in ''|\#*) continue ;; esac
  if [ ! -f "${ROOT}/${path}" ]; then
    echo "check-required-files: missing ${path}" >&2
    failures=$((failures + 1))
  fi
done < "$LIST"

[ "$failures" -eq 0 ] || {
  echo "check-required-files: ${failures} required file(s) missing" >&2
  exit 1
}

echo "check-required-files: template entry points present"
