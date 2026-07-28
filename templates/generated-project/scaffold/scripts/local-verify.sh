#!/usr/bin/env bash
#
# local-verify.sh — the one command engineering runs before any push.
# Mirrors the publish-gate part of mvp-safety-review. Exit non-zero on any failure.
#
# Steps:
#   1. structure-lint.sh + verify-gates.sh
#   2. Backend: `mvn -f backend/pom.xml clean verify`
#   3. Frontend: `npm test && npm run build`
#   4. docker-compose syntax check (does NOT run containers)

set -euo pipefail

cd "$(dirname "$0")/.."

JAVA_VERSION="$(java -version 2>&1 | awk -F'[\".]' '/version/ {print $2; exit}')"
case "$JAVA_VERSION" in 21|22|23|24|25) ;; *)
  echo "local-verify: Java 21+ is required (found '${JAVA_VERSION:-unavailable}')." >&2
  echo "Set JAVA_HOME to a JDK 21 installation or use the Replit java-21 module." >&2
  exit 1;; esac

if [ -f scripts/structure-lint.sh ]; then
  bash scripts/structure-lint.sh
fi

bash scripts/verify-gates.sh

# Coverage phase. The strict 0.80/0.70 gate is the pom default, so it applies
# unless this script explicitly opts into the relaxed mvp profile — a bare
# `mvn verify` is always strict, and forgetting a flag can never weaken the gate.
COVERAGE_PHASE="engineering"
COVERAGE_MAVEN_ARGS=()
if [ -f scripts/lib/coverage-phase.sh ]; then
  # shellcheck source=./lib/coverage-phase.sh
  . scripts/lib/coverage-phase.sh
  COVERAGE_PHASE="$(coverage_phase_read .)"
  coverage_phase_announce "${COVERAGE_PHASE}"
  phase_args="$(coverage_phase_maven_args "${COVERAGE_PHASE}")"
  [ -n "${phase_args}" ] && COVERAGE_MAVEN_ARGS=("${phase_args}")
fi

echo "==> Backend: mvn clean verify"
# ${arr[@]+...} because macOS ships bash 3.2, where "${arr[@]}" on an empty array
# is an "unbound variable" error under set -u. This array is empty in exactly one
# case — the engineering phase, which passes no -Pmvp — so the bug stayed hidden
# until the first project finalized its coverage.
mvn -f backend/pom.xml -B ${COVERAGE_MAVEN_ARGS[@]+"${COVERAGE_MAVEN_ARGS[@]}"} clean verify

if [ -f frontend/package.json ]; then
  echo "==> Frontend: lint + test + build"
  NPM_BIN="$(pwd)/backend/application/target/frontend-toolchain/node/npm"
  if [ -x "${NPM_BIN}" ]; then
    export PATH="$(dirname "${NPM_BIN}"):${PATH}"
  else
    NPM_BIN="npm"
  fi
  ( cd frontend && \
    { [ -f package-lock.json ] && "${NPM_BIN}" ci --no-audit --no-fund || "${NPM_BIN}" install --no-audit --no-fund; } && \
    "${NPM_BIN}" run lint && \
    "${NPM_BIN}" test && "${NPM_BIN}" run build )
fi

if [ -f docker-compose.yml ]; then
  echo "==> docker compose config (syntax check, no run)"
  docker compose --profile local config >/dev/null
fi

echo "==> local-verify.sh: all checks passed"
