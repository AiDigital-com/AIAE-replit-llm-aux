#!/usr/bin/env bash
#
# ci-verify-scaffold.sh — template CI: materialize scaffold as a real project,
# apply package name, run gates + full verify (reference sample aggregate kept).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SCAFFOLD="${REPO_ROOT}/templates/generated-project/scaffold"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

JAVA_VERSION="$(java -version 2>&1 | awk -F'[\".]' '/version/ {print $2; exit}')"
case "$JAVA_VERSION" in 21|22|23|24|25) ;; *)
  echo "ci-verify-scaffold: Java 21+ is required (found '${JAVA_VERSION:-unavailable}')." >&2
  exit 1;; esac

echo "==> Materialize scaffold to ${WORK}"
SCAFFOLD_ROOT="${SCAFFOLD}" \
  TEMPLATE_REPO_ROOT="${REPO_ROOT}" \
  MATERIALIZE_DEST="${WORK}" \
  bash "${SCAFFOLD}/scripts/materialize-project.sh" replitmvp

echo "==> Run the same phase-aware gate shipped to generated projects"
cd "${WORK}"
# The canonical scaffold intentionally retains one compilable sample aggregate;
# generated projects must strip it. This exception affects only that structural
# assertion—not Maven coverage, policy gates, frontend checks, or compose.
STRUCTURE_LINT_ALLOW_SAMPLE=1 bash scripts/local-verify.sh

echo "==> ci-verify-scaffold: passed"
