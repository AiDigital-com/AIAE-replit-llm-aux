#!/usr/bin/env bash
# Fixture tests for scripts/check-always-on-budget.sh.
#
# The positive case runs against the real repository, so CI fails when the actual
# always-on context grows past the budget. The logic cases use synthetic fixtures
# with a deliberately tiny budget: what matters is which files are counted, not
# how many words a real rule happens to have.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "${HERE}/../../.." && pwd)"
GATE="${REPO}/scripts/check-always-on-budget.sh"
. "${HERE}/../lib/assert.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

run_gate()       { ALWAYS_ON_BUDGET_ROOT="$1" bash "${GATE}"; }
run_gate_budget() { ALWAYS_ON_BUDGET_ROOT="$1" ALWAYS_ON_BUDGET_WORDS="$2" bash "${GATE}"; }

# 12 words, so a budget of 20 leaves room for exactly one more small file.
twelve_words() { printf 'one two three four five six seven eight nine ten eleven twelve\n'; }

synth() {
  local name="$1" dir="${WORK}/$1"
  rm -rf "$dir"; mkdir -p "${dir}/.claude/rules"
  twelve_words > "${dir}/CLAUDE.md"
  printf '%s' "$dir"
}

echo "==> positive: the real repository is within its declared budget"
gate_accepts "real always-on context" "${REPO}/.claude/rules" -- run_gate "${REPO}"

echo "==> what counts toward the budget"

F="$(synth under-budget)"
gate_accepts "CLAUDE.md alone under budget" "${F}" -- run_gate_budget "${F}" 20

F="$(synth always-on-rule-counted)"
printf -- '---\ndescription: an always-on rule\n---\n' > "${F}/.claude/rules/00-hard.md"
twelve_words >> "${F}/.claude/rules/00-hard.md"
gate_rejects "rule without paths: is charged to every task" "${F}" \
  "over the 20-word budget" -- run_gate_budget "${F}" 20

F="$(synth path-scoped-rule-exempt)"
printf -- '---\ndescription: a scoped rule\npaths:\n  - "backend/**"\n---\n' \
  > "${F}/.claude/rules/40-scoped.md"
twelve_words >> "${F}/.claude/rules/40-scoped.md"
twelve_words >> "${F}/.claude/rules/40-scoped.md"
gate_accepts "rule with paths: is not charged" "${F}" -- run_gate_budget "${F}" 20

# A `paths:` line in the body must not buy an exemption, or any rule could dodge
# the budget by mentioning the word.
F="$(synth paths-in-prose-not-exempt)"
printf -- '---\ndescription: looks scoped but is not\n---\n' > "${F}/.claude/rules/00-hard.md"
printf 'paths: this is prose about paths, not frontmatter\n' >> "${F}/.claude/rules/00-hard.md"
twelve_words >> "${F}/.claude/rules/00-hard.md"
gate_rejects "paths: mentioned in the body does not exempt a rule" "${F}" \
  "over the 20-word budget" -- run_gate_budget "${F}" 20

# No frontmatter at all cannot declare paths:, so the file is always-on.
F="$(synth no-frontmatter-counted)"
twelve_words > "${F}/.claude/rules/00-bare.md"
gate_rejects "rule with no frontmatter is treated as always-on" "${F}" \
  "over the 20-word budget" -- run_gate_budget "${F}" 20

echo "==> fail-closed on missing inputs"

F="$(synth no-claude-md)"
rm -f "${F}/CLAUDE.md"
gate_fails_closed "absent CLAUDE.md" "${F}" "no CLAUDE.md" -- run_gate "${F}"

F="$(synth no-rules-dir)"
rm -rf "${F}/.claude/rules"
gate_fails_closed "absent .claude/rules" "${F}" "no .claude/rules" -- run_gate "${F}"

gate_summary "test-gate-always-on-budget"
