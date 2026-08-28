#!/usr/bin/env bash
#
# replit-dev-backend.sh — backend task of the Replit "Run" workflow.
#
# Backend only: -Dskip.frontend=true keeps the frontend-maven-plugin chain out
# of the Maven build, so editing the SPA never triggers a Java rebuild and vice
# versa. The SPA is served separately by replit-dev-frontend.sh.
#
# Two invocations, not one: `mvn -f backend/application/pom.xml` alone resolves
# sibling modules from ~/.m2 rather than from the reactor, so the modules must
# be installed first. Selecting the reactor instead (-pl application -am) is
# not equivalent — spring-boot:run would then be attempted for every module.

set -euo pipefail

cd "$(dirname "$0")/.."

source scripts/replit-env.sh

if [ ! -f backend/pom.xml ]; then
  echo "[backend] Not generated yet - run: bash scripts/materialize-project.sh <app-name-package>"
  exit 0
fi

MVN_SKIPS=(-B -Dmaven.test.skip=true -Dcheckstyle.skip=true -Djacoco.skip=true -Dskip.frontend=true)

mvn -f backend/pom.xml "${MVN_SKIPS[@]}" install
exec mvn -f backend/application/pom.xml "${MVN_SKIPS[@]}" spring-boot:run
