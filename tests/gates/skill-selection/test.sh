#!/usr/bin/env bash
# Fixture tests for scripts/check-skill-selection.sh.
#
# Replaces scripts/test-skill-selection.sh, adding diagnostic attribution and
# fail-closed cases. Both shipped registries are checked against the real state,
# so a description edit that makes two skills compete fails in CI rather than at
# the moment an agent picks the wrong workflow.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "${HERE}/../../.." && pwd)"
GATE="${REPO}/scripts/check-skill-selection.sh"
. "${HERE}/../lib/assert.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

run_gate() { bash "${GATE}" "$1"; }

write_skill() {
  local registry="$1" name="$2" description="$3"
  mkdir -p "${registry}/${name}"
  printf -- '---\nname: %s\ndescription: %s\n---\n\n# %s\n' \
    "${name}" "${description}" "${name}" > "${registry}/${name}/SKILL.md"
}

registry() { local d="${WORK}/$1"; rm -rf "$d"; mkdir -p "$d"; printf '%s' "$d"; }

echo "==> positive: both shipped registries route unambiguously"
gate_accepts "real .claude/skills" "${REPO}/.claude/skills" -- run_gate "${REPO}/.claude/skills"
gate_accepts "real .agents/skills" "${REPO}/.agents/skills" -- run_gate "${REPO}/.agents/skills"

echo "==> violation classes"

# The exact defect this gate was built for: two skills whose `Use when` clause is
# word-for-word identical. No agent can choose between them.
R="$(registry identical-trigger)"
write_skill "$R" alpha "Review changed code for correctness. Use when reviewing a changed module."
write_skill "$R" beta  "Audit a module before release. Use when reviewing a changed module."
gate_rejects "identical trigger clauses" "$R" \
  "declare an identical trigger clause" -- run_gate "$R"

echo "==> vocabulary overlap is reported, not blocking"

# Overlap above REVIEW_AT is flagged for a human rather than failed. That is the
# right call for a wording heuristic — a Jaccard score should not block a PR — but
# it means the report itself is the whole value, so assert the report. Calibration:
# the pair removed from this repository scored 0.47, the highest legitimate pair
# scores 0.20, and the threshold sits between them.
R="$(registry high-overlap)"
write_skill "$R" gamma \
  "Whole-repository compliance audit against discovered rule sources for periodic health checks and migration validation."
write_skill "$R" delta \
  "Whole-repository compliance audit against installed rule sources for periodic health checks and migration validation."
gate_emits "overlapping vocabulary is surfaced for manual review" "$R" \
  "require manual review" -- run_gate "$R"

# Distinct domains may share review vocabulary; that is the case the threshold is
# deliberately set above, and it must keep passing.
R="$(registry distinct-domains)"
write_skill "$R" backend-review \
  "Review changed Java and Spring backend code against installed architecture rules. Use after backend changes."
write_skill "$R" frontend-review \
  "Review changed React and CSS frontend code for accessibility and responsive layout. Use after frontend changes."
gate_accepts "shared vocabulary separated by domain" "$R" -- run_gate "$R"

echo "==> fail-closed on missing inputs"

gate_fails_closed "registry directory that does not exist" "${WORK}" \
  "no registry at" -- run_gate "${WORK}/definitely-absent"

# A registry the gate cannot read descriptions from proves nothing about
# selection, so it must not report success.
R="$(registry no-descriptions)"
mkdir -p "$R/nameless"
printf '# no frontmatter at all\n' > "$R/nameless/SKILL.md"
gate_fails_closed "registry with no readable descriptions" "$R" \
  "no skills with descriptions" -- run_gate "$R"

gate_summary "test-gate-skill-selection"
