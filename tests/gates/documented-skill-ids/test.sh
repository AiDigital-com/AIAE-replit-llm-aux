#!/usr/bin/env bash
# Fixture tests for scripts/check-documented-skill-ids.sh.
#
# Replaces scripts/test-documented-skill-ids.sh, which asserted exit status only.
# This gate guards the documentation that tells an agent which skills exist, so
# when it drifts the agent is told to invoke workflows that were never installed.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "${HERE}/../../.." && pwd)"
GATE="${REPO}/scripts/check-documented-skill-ids.sh"
. "${HERE}/../lib/assert.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

BASE="${WORK}/base"
mkdir -p "${BASE}/.claude/agent_docs"
cp "${REPO}/agent-payload.skills" "${BASE}/agent-payload.skills"
cp "${REPO}/.claude/agent_docs/skill-selection.md" "${BASE}/.claude/agent_docs/"
cp "${REPO}/.claude/agent_docs/index.md" "${BASE}/.claude/agent_docs/"
cp "${REPO}/AI-DEVELOPMENT-GUIDE.md" "${BASE}/AI-DEVELOPMENT-GUIDE.md"

run_gate() { DOCUMENTED_SKILL_ROOT="$1" bash "${GATE}"; }
fixture() { local d="${WORK}/$1"; rm -rf "$d"; cp -R "${BASE}" "$d"; printf '%s' "$d"; }

echo "==> positive"
gate_accepts "real documentation references only shipped skills" "${BASE}" -- run_gate "${BASE}"

echo "==> violation classes"

# The generic name was deliberately removed from the payload; documentation that
# still names it would send the agent to a skill that is not installed.
F="$(fixture unshipped-skill-referenced)"
ruby -pi -e 'gsub("aiae-rule-compliance-audit", "rule-compliance-audit")' \
  "${F}/.claude/agent_docs/skill-selection.md" \
  "${F}/.claude/agent_docs/index.md" \
  "${F}/AI-DEVELOPMENT-GUIDE.md"
gate_rejects "documentation naming an unshipped skill" "${F}" \
  "references unshipped skill" -- run_gate "${F}"

# AI-DEVELOPMENT-GUIDE.md is a copy of skill-selection.md; a divergence means one
# of the two is stale and the agent's guidance depends on which it reads.
F="$(fixture guide-drifted)"
printf '\nAn edit applied to only one of the two copies.\n' \
  >> "${F}/AI-DEVELOPMENT-GUIDE.md"
gate_rejects "guide diverged from skill-selection.md" "${F}" \
  "drifted from skill-selection.md" -- run_gate "${F}"

echo "==> fail-closed on missing inputs"

F="$(fixture no-payload)"
rm -f "${F}/agent-payload.skills"
gate_fails_closed "absent agent-payload.skills" "${F}" \
  "missing required file" -- run_gate "${F}"

F="$(fixture no-skill-selection)"
rm -f "${F}/.claude/agent_docs/skill-selection.md"
gate_fails_closed "absent skill-selection.md" "${F}" \
  "missing required file" -- run_gate "${F}"

# An empty document must not read as "nothing to check, therefore fine".
F="$(fixture no-references-at-all)"
: > "${F}/.claude/agent_docs/skill-selection.md"
: > "${F}/AI-DEVELOPMENT-GUIDE.md"
: > "${F}/.claude/agent_docs/index.md"
gate_fails_closed "documentation with no skill references" "${F}" \
  "no documented skill references found" -- run_gate "${F}"

gate_summary "test-gate-documented-skill-ids"
