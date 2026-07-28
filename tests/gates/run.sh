#!/usr/bin/env bash
# run.sh — run the curated fixture suites for critical custom gates.
#
# Each included suite proves both acceptance and a rejection with the expected
# diagnostic. Not every small check needs a parallel test directory: orchestration
# and low-risk structural assertions are covered by their existing integration
# tests.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

suites=0 failed=0
for suite in "${HERE}"/*/test.sh; do
  [ -f "$suite" ] || continue
  name="$(basename "$(dirname "$suite")")"
  echo "=== gate suite: ${name}"
  if bash "$suite"; then :; else failed=$((failed + 1)); fi
  suites=$((suites + 1))
  echo ""
done

echo ""
echo "==> gate suites: ${suites} run, ${failed} failing group(s)"
[ "$failed" -eq 0 ]
