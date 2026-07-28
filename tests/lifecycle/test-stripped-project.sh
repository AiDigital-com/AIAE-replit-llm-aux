#!/usr/bin/env bash
# Build both lifecycle states the ordinary initialization path creates:
# first the empty project immediately after the reference sample is removed,
# then a project where a real aggregate has replaced that sample.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "${HERE}/../.." && pwd)"
SCAFFOLD="${REPO}/templates/generated-project/scaffold"
WORK="$(mktemp -d)"
EMPTY_WORK="$(mktemp -d)"
trap 'rm -rf "$WORK" "$EMPTY_WORK"' EXIT

echo "==> stripped-project: materialize"
mkdir -p "${WORK}/scripts"
cp -R "${SCAFFOLD}/scripts/." "${WORK}/scripts/"
SCAFFOLD_ROOT="${SCAFFOLD}" \
  TEMPLATE_REPO_ROOT="${REPO}" \
  MATERIALIZE_DEST="${WORK}" \
  bash "${WORK}/scripts/materialize-project.sh" strippedapp

echo "==> stripped-project: verify empty post-initialization state"
cp -R "${WORK}/." "${EMPTY_WORK}/"
(
  cd "$EMPTY_WORK"
  bash scripts/strip-scaffold-samples.sh
  bash scripts/structure-lint.sh
  bash scripts/verify-gates.sh
  mvn -f backend/pom.xml -Pmvp -pl service -am verify
)

echo "==> stripped-project: install replacement aggregate"
bash "${HERE}/install-fixture-aggregate.sh" "${WORK}" widget

echo "==> stripped-project: remove reference sample"
(
  cd "$WORK"
  bash scripts/strip-scaffold-samples.sh
  bash scripts/structure-lint.sh
  bash scripts/verify-gates.sh
)

echo "==> stripped-project: full backend and frontend verification"
(cd "$WORK" && bash scripts/local-verify.sh)

echo "==> test-stripped-project: passed"
