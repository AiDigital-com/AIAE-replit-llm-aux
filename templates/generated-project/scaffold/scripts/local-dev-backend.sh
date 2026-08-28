#!/usr/bin/env bash
#
# local-dev-backend.sh — backend only, on a developer machine.
#
# The frontend is NOT built here: -Dskip.frontend=true disables the
# frontend-maven-plugin chain (npm ci → generate:api → vite build) declared in
# backend/application/pom.xml. Run scripts/local-dev-frontend.sh in a second
# terminal for the SPA; its dev server proxies /api to this process.
#
# Two Maven invocations, not one: `mvn -f backend/application/pom.xml` alone
# resolves sibling modules from ~/.m2 rather than from the reactor, so
# external-services/service/domain must be installed first. Selecting the
# reactor instead (-pl application -am) is not equivalent — spring-boot:run
# would then be attempted for every selected module.

set -euo pipefail

cd "$(dirname "$0")/.."

if [ -f .env.local ]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi

export SPRING_PROFILES_ACTIVE="${SPRING_PROFILES_ACTIVE:-local}"
export PORT="${PORT:-5000}"

# Homebrew machines often default to a newer JDK; the stack is locked to 21.
if command -v /usr/libexec/java_home >/dev/null 2>&1; then
  JAVA_21_HOME="$(/usr/libexec/java_home -v 21 2>/dev/null || true)"
  if [ -n "${JAVA_21_HOME}" ]; then
    export JAVA_HOME="${JAVA_21_HOME}"
    export PATH="${JAVA_HOME}/bin:${PATH}"
  fi
fi

MVN_SKIPS=(-B -Dmaven.test.skip=true -Dcheckstyle.skip=true -Djacoco.skip=true -Dskip.frontend=true)

mvn -f backend/pom.xml "${MVN_SKIPS[@]}" install
exec mvn -f backend/application/pom.xml "${MVN_SKIPS[@]}" spring-boot:run
