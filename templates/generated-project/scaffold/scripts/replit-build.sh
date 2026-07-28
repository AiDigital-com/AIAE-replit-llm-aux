#!/usr/bin/env bash
#
# replit-build.sh — invoked by .replit [deployment].build.
#
# One Maven invocation builds BOTH the React SPA and the Spring fat jar:
#   - openapi-generator (generate-sources) emits Spring interfaces from openapi.yaml
#   - frontend-maven-plugin (generate-resources → process-resources) runs
#     npm ci → npm run generate:api → npm run build → outputs to
#     ../backend/application/src/main/resources/static/
#   - spring-boot-maven-plugin (package) repackages everything (jar + SPA + changelogs) into one fat jar
#
# Skip frontend during pure-backend local dev with -Dskip.frontend=true; never in deployment.

set -euo pipefail

cd "$(dirname "$0")/.."   # works from root/scripts and scaffold/scripts

if [ -f scripts/replit-env.sh ]; then
  . scripts/replit-env.sh
fi

if [ -f scripts/structure-lint.sh ]; then
  bash scripts/structure-lint.sh
fi

# Replit workspaces persist target/ between builds. Clean first so package
# moves/renames cannot leave stale component classes in the deployable jar.
mvn -f backend/pom.xml -B -DskipTests clean package

# Extract the Spring Boot fat jar into an exploded layout (thin launcher jar +
# lib/). On Replit's Reserved VM the CPU is throttled during the cold-boot
# window, and having the JVM open/index the ~80MB nested fat jar pushes first
# port-bind past the deployment's ~60s port-check, causing an infinite restart
# loop. Running the extracted layout loads classes from plain files and binds
# the port well within the window. replit-run.sh prefers this layout.
JAR="$(ls backend/application/target/*.jar 2>/dev/null | grep -v '\.original$' | head -n1)"
if [ -z "${JAR}" ]; then
  echo "ERROR: no fat jar produced by 'mvn package'." >&2
  exit 1
fi
rm -rf backend/application/target/extracted
java -Djarmode=tools -jar "${JAR}" extract --destination backend/application/target/extracted
