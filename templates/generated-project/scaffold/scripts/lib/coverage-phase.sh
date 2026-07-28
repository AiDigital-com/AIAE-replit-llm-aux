#!/usr/bin/env bash
#
# coverage-phase.sh — single source of truth for which coverage phase a project
# is in. Sourced, not executed.
#
# The phase is a committed property of the project (`.template-phase`), not a
# property of whoever is running the build. That matters: keying the gate off the
# runtime (Replit vs local, which agent is driving) would mean the same commit
# passes in one place and fails in another, env vars are absent in CI and
# forgeable by an agent chasing a green build, and there would be no record of
# when coverage was relaxed. A committed file gives one answer per commit and
# shows up in review.
#
# Phases:
#   mvp          relaxed floor (see the `mvp` profile in backend/pom.xml) so
#                coverage never blocks feature discovery
#   engineering  the strict default (0.80 line / 0.70 branch), non-negotiable
#
# Usage:
#   . scripts/lib/coverage-phase.sh
#   phase="$(coverage_phase_read "${ROOT}")"
#   read -ra extra <<< "$(coverage_phase_maven_args "${phase}")"
#   mvn -f backend/pom.xml "${extra[@]}" clean verify

COVERAGE_PHASE_FILE=".template-phase"

# Minimum acceptable thresholds. check-coverage-integrity.sh enforces that the
# pom never drops below these, so lowering a gate requires editing this contract
# too — a much more visible change than tweaking a number in a pom.
COVERAGE_STRICT_LINE_MIN="0.80"
COVERAGE_STRICT_BRANCH_MIN="0.70"
COVERAGE_MVP_LINE_MIN="0.30"
COVERAGE_MVP_BRANCH_MIN="0.25"

# Read and validate the phase. Defaults to `engineering` when the marker is
# absent: an unknown project is treated as needing the strict gate, so a missing
# or deleted file can never silently relax coverage.
coverage_phase_read() {
  local root="${1:-.}"
  local file="${root}/${COVERAGE_PHASE_FILE}"
  local value

  if [ ! -f "$file" ]; then
    printf 'engineering'
    return 0
  fi

  value="$(tr -d '[:space:]' < "$file")"
  case "$value" in
    mvp|engineering) printf '%s' "$value" ;;
    "")
      echo "coverage-phase: ${COVERAGE_PHASE_FILE} is empty — expected 'mvp' or 'engineering'" >&2
      return 1 ;;
    *)
      echo "coverage-phase: ${COVERAGE_PHASE_FILE} says '${value}' — expected 'mvp' or 'engineering'" >&2
      return 1 ;;
  esac
}

# Maven arguments for a phase. Relaxation goes through a pom profile rather than
# a -D override, so the numbers stay visible in the pom and the integrity check
# can ban -Djacoco.* overrides outright.
coverage_phase_maven_args() {
  case "${1:-engineering}" in
    mvp) printf -- '-Pmvp' ;;
    *)   printf '' ;;
  esac
}

# Announce the phase. During mvp this is deliberately loud: a relaxed gate that
# nobody notices is how a project reaches handoff with no tests.
coverage_phase_announce() {
  local phase="${1:-engineering}"
  if [ "$phase" = "mvp" ]; then
    cat <<EOF
==> coverage phase: MVP (relaxed floor ${COVERAGE_MVP_LINE_MIN} line / ${COVERAGE_MVP_BRANCH_MIN} branch)
    Coverage is intentionally relaxed while the product is being built.
    Before handoff you MUST finalize coverage:
      1. raise coverage to ${COVERAGE_STRICT_LINE_MIN} line / ${COVERAGE_STRICT_BRANCH_MIN} branch
      2. set ${COVERAGE_PHASE_FILE} to 'engineering'
      3. bash scripts/local-verify.sh
    prepare-engineering-handoff.sh refuses to run while the phase is 'mvp'.
EOF
  else
    echo "==> coverage phase: ENGINEERING (strict ${COVERAGE_STRICT_LINE_MIN} line / ${COVERAGE_STRICT_BRANCH_MIN} branch)"
  fi
}
