#!/usr/bin/env bash
# Fixture tests for scaffold/scripts/lib/check-coverage-integrity.sh.
#
# This gate is the only thing standing between "the project declares strict
# coverage" and "the project declares strict coverage but nothing enforces it".
# A false green here is expensive and invisible: a project hands off believing it
# cleared 0.80 while the real gate was relaxed or skipped.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "${HERE}/../../.." && pwd)"
SCAFFOLD="${REPO}/templates/generated-project/scaffold"
GATE="${SCAFFOLD}/scripts/lib/check-coverage-integrity.sh"
. "${HERE}/../lib/assert.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

BASE="${WORK}/base"
mkdir -p "${BASE}/backend" "${BASE}/scripts/lib" "${BASE}/.github/workflows"
cp "${SCAFFOLD}/backend/pom.xml" "${BASE}/backend/pom.xml"
cp "${SCAFFOLD}/.template-phase" "${BASE}/.template-phase"
for s in local-verify.sh verify-gates.sh structure-lint.sh; do
  [ -f "${SCAFFOLD}/scripts/${s}" ] && cp "${SCAFFOLD}/scripts/${s}" "${BASE}/scripts/${s}"
done
cp "${SCAFFOLD}"/scripts/lib/*.sh "${BASE}/scripts/lib/" 2>/dev/null || true
cp "${REPO}/templates/generated-project/.github/workflows/ci.yml" \
  "${BASE}/.github/workflows/ci.yml" 2>/dev/null || true

run_gate() { VERIFY_ROOT="$1" bash "${GATE}"; }
fixture() { local d="${WORK}/$1"; rm -rf "$d"; cp -R "${BASE}" "$d"; printf '%s' "$d"; }
phase_of() { tr -d '[:space:]' < "$1/.template-phase"; }

echo "==> positive: both declared phases are accepted"
echo "    baseline phase: $(phase_of "${BASE}")"
gate_accepts "scaffold default phase" "${BASE}" -- run_gate "${BASE}"

F="$(fixture engineering-phase)"
printf 'engineering\n' > "${F}/.template-phase"
gate_accepts "engineering phase" "${F}" -- run_gate "${F}"

echo "==> phase marker"

F="$(fixture phase-absent)"
rm -f "${F}/.template-phase"
gate_rejects "phase marker deleted" "${F}" \
  ".template-phase is missing" -- run_gate "${F}"

# Regression is detected from git history, so this case needs real history.
F="$(fixture phase-regression)"
(
  cd "${F}"
  git init -q .
  git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  printf 'engineering\n' > .template-phase
  git add .template-phase
  git -c user.email=t@t -c user.name=t commit -q -m "finalize coverage"
  printf 'mvp\n' > .template-phase
  git add .template-phase
  git -c user.email=t@t -c user.name=t commit -q -m "relax again"
)
gate_rejects "engineering reverted to mvp in history" "${F}" \
  "was reverted from 'engineering' back to 'mvp'" -- run_gate "${F}"

echo "==> thresholds"

F="$(fixture default-line-lowered)"
sed -i.bak 's|<jacoco.line.coverage>0.80</jacoco.line.coverage>|<jacoco.line.coverage>0.10</jacoco.line.coverage>|' \
  "${F}/backend/pom.xml" && rm -f "${F}/backend/pom.xml.bak"
gate_rejects "strict default line threshold lowered" "${F}" \
  "default jacoco.line.coverage is" -- run_gate "${F}"

F="$(fixture default-branch-lowered)"
sed -i.bak 's|<jacoco.branch.coverage>0.70</jacoco.branch.coverage>|<jacoco.branch.coverage>0.05</jacoco.branch.coverage>|' \
  "${F}/backend/pom.xml" && rm -f "${F}/backend/pom.xml.bak"
gate_rejects "strict default branch threshold lowered" "${F}" \
  "default jacoco.branch.coverage is" -- run_gate "${F}"

echo "==> bypasses on verification surfaces"

F="$(fixture skip-flag-in-gate)"
printf '\n# injected\nmvn -f backend/pom.xml -Djacoco.skip=true verify\n' \
  >> "${F}/scripts/local-verify.sh"
gate_rejects "skip flag added to a verification script" "${F}" \
  "coverage/test bypass on a verification surface" -- run_gate "${F}"

F="$(fixture threshold-override-in-gate)"
printf '\n# injected\nmvn -Djacoco.line.coverage=0.0 verify\n' \
  >> "${F}/scripts/verify-gates.sh"
gate_rejects "threshold override in a verification script" "${F}" \
  "threshold override on a verification surface" -- run_gate "${F}"

F="$(fixture skip-flag-in-ci)"
if [ -f "${F}/.github/workflows/ci.yml" ]; then
  printf '\n        run: mvn -f backend/pom.xml -DskipTests verify\n' \
    >> "${F}/.github/workflows/ci.yml"
  gate_rejects "skip flag added to a CI workflow" "${F}" \
    "coverage/test bypass on a verification surface" -- run_gate "${F}"
else
  echo "  SKIP: generated-project CI workflow not present in this checkout"
fi

# The gate ignores lines whose trimmed form starts with `#`, so prose and
# disabled commands do not trip it. That exemption is load-bearing: without this
# case, narrowing it later would look like a pass.
F="$(fixture skip-flag-only-in-a-comment)"
printf '\n# Never do this: mvn -Djacoco.skip=true verify\n' \
  >> "${F}/scripts/local-verify.sh"
gate_accepts "skip flag mentioned only in a comment" "${F}" -- run_gate "${F}"

F="$(fixture skip-property-in-pom)"
sed -i.bak 's|</properties>|  <maven.test.skip>true</maven.test.skip>\n    </properties>|' \
  "${F}/backend/pom.xml" && rm -f "${F}/backend/pom.xml.bak"
gate_rejects "test-skip property set in a pom" "${F}" \
  "coverage/test skip property in" -- run_gate "${F}"

echo "==> jacoco excludes"

F="$(fixture exclude-handwritten-code)"
sed -i.bak 's|<exclude>\*\*/api/v1/invoker/\*\*</exclude>|<exclude>**/service/**</exclude>|' \
  "${F}/backend/pom.xml" && rm -f "${F}/backend/pom.xml.bak"
gate_rejects "coverage exclude over hand-written code" "${F}" \
  "is not generated code" -- run_gate "${F}"

echo "==> fail-closed on a missing backend"

# Deleting the pom used to pass as "skipped", which made it a silent way to
# disable coverage enforcement in a full-stack project.
F="$(fixture pom-absent)"
rm -f "${F}/backend/pom.xml"
gate_rejects "absent backend/pom.xml with no declared shape" "${F}" \
  "backend/pom.xml is absent" -- run_gate "${F}"

# The skip has to be an explicit, committed declaration. Nothing infers the shape
# from which files are missing, so this is the only path that reaches exit 0
# without a pom.
F="$(fixture pom-absent-declared-frontend-only)"
rm -f "${F}/backend/pom.xml"
printf 'frontend-only\n' > "${F}/.project-shape"
gate_accepts "absent backend/pom.xml with .project-shape=frontend-only" "${F}" -- run_gate "${F}"

# A shape marker with any other value must not buy the skip.
F="$(fixture pom-absent-unknown-shape)"
rm -f "${F}/backend/pom.xml"
printf 'full-stack\n' > "${F}/.project-shape"
gate_rejects "absent backend/pom.xml with a non-frontend-only shape" "${F}" \
  "backend/pom.xml is absent" -- run_gate "${F}"

gate_summary "test-gate-coverage-integrity"
