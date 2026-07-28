#!/usr/bin/env bash
# assert.sh — shared assertions for enforcement-gate fixture tests.
#
# An enforcement gate without a negative test is not proven. But asserting only
# a non-zero exit is not enough either: a gate with a syntax error, a missing
# interpreter, or a typo'd path also exits non-zero, so an exit-code-only test
# reports success while the gate checks nothing.
#
# Demonstrated on this repository: replacing check-production-magic-values.sh
# with invalid Bash left its negative case in test-check-production-scanners.sh
# reporting a pass. Only the paired positive case caught it; a gate without such
# a pair would have gone fully green.
#
# So every rejection assertion here requires the gate to say *why* it rejected,
# and separately rejects output that looks like a crash rather than a verdict.
#
# Each gate case asserts:
#   1. exit status (0 for accept, non-zero for reject)
#   2. for a rejection, the specific diagnostic the gate is supposed to emit
#   3. no crash signature in the output, whatever the exit status
#   4. the fixture is byte-identical afterwards — gates are read-only
#
# Usage:
#   . "$(dirname "$0")/../lib/assert.sh"
#   gate_accepts "label" "$FIXTURE" -- bash /path/to/gate.sh
#   gate_rejects "label" "$FIXTURE" "expected diagnostic" -- bash /path/to/gate.sh
#   gate_fails_closed "label" "$FIXTURE" "expected diagnostic" -- bash /path/to/gate.sh
#   gate_summary

GATE_PASS=0
GATE_FAIL=0

if command -v shasum >/dev/null 2>&1; then _GATE_SHA_CMD=(shasum -a 256)
else _GATE_SHA_CMD=(sha256sum)
fi

# A gate must never mutate what it inspects. Snapshot path+hash of every file.
# One hashing process for the whole tree: a process per file made a suite of ten
# cases over a few hundred files take minutes, which is a reason to stop running
# the tests. Paths are relative so fixtures in different temp dirs compare equal.
_gate_fingerprint() {
  local root="$1"
  [ -d "$root" ] || { printf 'ABSENT\n'; return 0; }
  ( cd "$root" && find . -type f -print0 \
      | LC_ALL=C sort -z \
      | xargs -0 "${_GATE_SHA_CMD[@]}" 2>/dev/null ) || true
}

# Output that indicates the gate broke rather than reached a verdict. Anything
# here invalidates the case even when the exit status looked right.
# `|| true` and no pipeline: a caller running with `set -o pipefail` would
# otherwise die here on grep's no-match exit status, before any assertion ran.
_gate_crash_signature() {
  local hits
  hits="$(grep -nEi \
    'syntax error|unexpected token|command not found|Traceback \(most recent call last\)|: line [0-9]+: [^ ]+: not found|Permission denied' \
    "$1" 2>/dev/null || true)"
  printf '%s' "$(printf '%s\n' "$hits" | sed -n '1,3p')"
}

_gate_report_context() {
  local label="$1" out="$2"
  echo "    --- gate output (first 20 lines) ---" >&2
  sed -n '1,20p' "$out" | sed 's/^/    /' >&2
  echo "    --- end ---" >&2
}

# _gate_run <label> <fixture> <expect-zero:0|1> <expected-diagnostic-or-empty> -- cmd...
_gate_run() {
  local label="$1" fixture="$2" expect_zero="$3" expected="$4"
  shift 4
  [ "${1:-}" = "--" ] && shift

  local before after out status
  before="$(_gate_fingerprint "$fixture")"
  out="$(mktemp)"

  set +e
  "$@" >"$out" 2>&1
  status=$?
  set -e

  after="$(_gate_fingerprint "$fixture")"

  local crash
  crash="$(_gate_crash_signature "$out")"
  if [ -n "$crash" ]; then
    echo "  FAIL: ${label} — gate crashed instead of reaching a verdict" >&2
    printf '%s\n' "$crash" | sed 's/^/    /' >&2
    GATE_FAIL=$((GATE_FAIL + 1)); rm -f "$out"; return 0
  fi

  if [ "$expect_zero" -eq 1 ] && [ "$status" -ne 0 ]; then
    echo "  FAIL: ${label} — expected the gate to accept, got exit ${status}" >&2
    _gate_report_context "$label" "$out"
    GATE_FAIL=$((GATE_FAIL + 1)); rm -f "$out"; return 0
  fi

  if [ "$expect_zero" -eq 0 ] && [ "$status" -eq 0 ]; then
    echo "  FAIL: ${label} — expected the gate to reject, it accepted" >&2
    _gate_report_context "$label" "$out"
    GATE_FAIL=$((GATE_FAIL + 1)); rm -f "$out"; return 0
  fi

  if [ -n "$expected" ] && ! grep -qF -- "$expected" "$out"; then
    echo "  FAIL: ${label} — rejected, but not for the stated reason" >&2
    echo "    expected diagnostic to contain: ${expected}" >&2
    _gate_report_context "$label" "$out"
    GATE_FAIL=$((GATE_FAIL + 1)); rm -f "$out"; return 0
  fi

  if [ "$before" != "$after" ]; then
    echo "  FAIL: ${label} — gate mutated its fixture; enforcement gates are read-only" >&2
    diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed 's/^/    /' >&2
    GATE_FAIL=$((GATE_FAIL + 1)); rm -f "$out"; return 0
  fi

  echo "  PASS: ${label}"
  GATE_PASS=$((GATE_PASS + 1))
  rm -f "$out"
}

gate_accepts()      { _gate_run "$1" "$2" 1 "" "${@:3}"; }
gate_rejects()      { _gate_run "$1" "$2" 0 "$3" "${@:4}"; }
# For a gate that also classifies: accepting is not enough, it must report the
# right answer. check-agent-surfaces.sh emits `active` or `handoff`, and callers
# branch on that, so a gate returning the wrong mode while exiting 0 is a silent
# defect an exit-status assertion cannot see.
gate_emits()        { _gate_run "$1" "$2" 1 "$3" "${@:4}"; }
# Semantically distinct from a rejection: a missing prerequisite (absent required
# file, unavailable interpreter) must fail loudly, never be treated as "nothing
# to check, therefore fine".
gate_fails_closed() { _gate_run "$1" "$2" 0 "$3" "${@:4}"; }

gate_summary() {
  local name="$1"
  echo ""
  echo "==> ${name}: ${GATE_PASS} passed, ${GATE_FAIL} failed"
  [ "$GATE_FAIL" -eq 0 ]
}
