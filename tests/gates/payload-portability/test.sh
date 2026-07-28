#!/usr/bin/env bash
# Fixture tests for scripts/check-payload-portability.sh.
#
# The baseline fixture is a copy of the real template state rather than a
# hand-written tree. A hand-written fixture drifts from the gate it guards and
# starts passing for the wrong reason; a copy cannot. Each violation case is that
# same baseline with exactly one defect injected, so a failure names one cause.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "${HERE}/../../.." && pwd)"
GATE="${REPO}/scripts/check-payload-portability.sh"
. "${HERE}/../lib/assert.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# Baseline: everything the gate reads, nothing else.
BASE="${WORK}/base"
mkdir -p "${BASE}/.claude" "${BASE}/.agents" "${BASE}/templates/generated-project"
cp "${REPO}/agent-payload.skills" "${REPO}/.llm-aux-managed-skills" "${BASE}/"
cp "${REPO}/CLAUDE.md" "${BASE}/" 2>/dev/null || true
for d in skills agent_docs rules; do
  [ -d "${REPO}/.claude/${d}" ] && cp -R "${REPO}/.claude/${d}" "${BASE}/.claude/${d}"
done
cp -R "${REPO}/.agents/skills" "${BASE}/.agents/skills"
# Canonical docs only; the scaffold is excluded by the gate itself.
while IFS= read -r doc; do
  rel="${doc#"${REPO}/"}"
  mkdir -p "${BASE}/$(dirname "${rel}")"
  cp "${doc}" "${BASE}/${rel}"
done < <(find "${REPO}/templates/generated-project" -name '*.md' -not -path '*/scaffold/*' -type f)

run_gate() { PAYLOAD_PORTABILITY_ROOT="$1" bash "${GATE}"; }

# A managed skill and a project-owned skill, read from the real selection so the
# cases stay correct when the payload changes.
MANAGED_SKILL="$(grep -vE '^[[:space:]]*(#|$)' "${BASE}/.llm-aux-managed-skills" | head -1)"
PROJECT_SKILL="$(
  grep -vE '^[[:space:]]*(#|$)' "${BASE}/agent-payload.skills" \
    | grep -vxF -f <(grep -vE '^[[:space:]]*(#|$)' "${BASE}/.llm-aux-managed-skills") | head -1
)"
echo "==> managed skill under test: ${MANAGED_SKILL}; project-owned: ${PROJECT_SKILL}"

# Each case gets its own copy so a mutation cannot leak into the next.
fixture() {
  local name="$1" dir="${WORK}/$1"
  rm -rf "${dir}"; cp -R "${BASE}" "${dir}"; printf '%s' "${dir}"
}

echo "==> positive"
gate_accepts "real template state is portable" "${BASE}" -- run_gate "${BASE}"

echo "==> violation classes"

F="$(fixture missing-reference)"
printf '\nSee `.claude/agent_docs/does-not-exist.md` for details.\n' \
  >> "${F}/.claude/skills/${PROJECT_SKILL}/SKILL.md"
gate_rejects "a cited path that exists nowhere" "${F}" \
  "cites a missing template-state path" -- run_gate "${F}"

F="$(fixture registry-divergence)"
printf '\nThis line exists only in the Claude registry.\n' \
  >> "${F}/.claude/skills/${PROJECT_SKILL}/SKILL.md"
gate_rejects "project skill differing between registries" "${F}" \
  "differs between .claude/skills and .agents/skills" -- run_gate "${F}"

F="$(fixture managed-divergence)"
printf '\nHand-edited content in a generated file.\n' \
  >> "${F}/.claude/skills/${MANAGED_SKILL}/SKILL.md"
gate_rejects "generated skill edited beyond its provenance target" "${F}" \
  "differs between registries beyond its provenance target" -- run_gate "${F}"

F="$(fixture template-leak)"
for t in claude agents; do
  printf '\nCanonical: `templates/generated-project/testing/testing-policy.md`.\n' \
    >> "${F}/.${t}/skills/${MANAGED_SKILL}/SKILL.md"
done
gate_rejects "common skill citing the Replit template tree" "${F}" \
  "depends on the Replit template tree" -- run_gate "${F}"

F="$(fixture missing-provenance)"
for t in claude agents; do
  sed '/Generated file. Do not edit directly./d' \
    "${F}/.${t}/skills/${MANAGED_SKILL}/SKILL.md" > "${F}/tmp" \
    && mv "${F}/tmp" "${F}/.${t}/skills/${MANAGED_SKILL}/SKILL.md"
done
gate_rejects "generated skill stripped of provenance" "${F}" \
  "lacks provenance in" -- run_gate "${F}"

F="$(fixture name-mismatch)"
sed "s/^name: ${PROJECT_SKILL}\$/name: renamed-out-of-band/" \
  "${F}/.claude/skills/${PROJECT_SKILL}/SKILL.md" > "${F}/tmp" \
  && mv "${F}/tmp" "${F}/.claude/skills/${PROJECT_SKILL}/SKILL.md"
gate_rejects "directory name not matching frontmatter" "${F}" \
  "directory/frontmatter mismatch" -- run_gate "${F}"

F="$(fixture payload-skill-absent)"
rm -rf "${F}/.agents/skills/${PROJECT_SKILL}"
gate_rejects "declared payload skill missing from a registry" "${F}" \
  "missing from .agents/skills" -- run_gate "${F}"

F="$(fixture duplicated-document)"
CANON="$(find "${F}/templates/generated-project" -name '*.md' -type f | head -1)"
mkdir -p "${F}/.claude/agent_docs"
cp "${CANON}" "${F}/.claude/agent_docs/duplicated-canonical-source.md"
gate_rejects "canonical document copied verbatim into the payload" "${F}" \
  "duplicated document, no single canonical source" -- run_gate "${F}"

echo "==> fail-closed on missing inputs"

F="$(fixture no-payload-list)"
rm -f "${F}/agent-payload.skills"
gate_fails_closed "absent agent-payload.skills" "${F}" \
  "missing agent-payload.skills" -- run_gate "${F}"

F="$(fixture no-managed-list)"
rm -f "${F}/.llm-aux-managed-skills"
gate_fails_closed "absent .llm-aux-managed-skills" "${F}" \
  "missing .llm-aux-managed-skills" -- run_gate "${F}"

gate_summary "test-gate-payload-portability"
