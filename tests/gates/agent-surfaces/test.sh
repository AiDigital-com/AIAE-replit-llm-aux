#!/usr/bin/env bash
# Fixture tests for scaffold/scripts/lib/check-agent-surfaces.sh.
#
# This gate does two jobs, and both need asserting. It rejects an incoherent
# runtime surface, and it classifies a coherent one as `active` or `handoff`.
# verify-gates.sh and prepare-engineering-handoff.sh branch on that word, so a
# gate that exits 0 with the wrong mode sends both down the wrong path while
# every exit status looks correct.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "${HERE}/../../.." && pwd)"
GATE="${REPO}/templates/generated-project/scaffold/scripts/lib/check-agent-surfaces.sh"
. "${HERE}/../lib/assert.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

run_gate() { bash "${GATE}" "$1"; }

# A project with only the Claude surface: what handoff leaves behind.
claude_only() {
  local dir="${WORK}/$1"
  rm -rf "$dir"
  mkdir -p "${dir}/.claude/skills/verification-gate"
  printf '# CLAUDE.md\n' > "${dir}/CLAUDE.md"
  printf -- '---\nname: verification-gate\ndescription: d\n---\nbody\n' \
    > "${dir}/.claude/skills/verification-gate/SKILL.md"
  printf '%s' "$dir"
}

# Adds the full Replit surface on top: an active dual-agent project.
add_replit() {
  local dir="$1"
  mkdir -p "${dir}/.agents/skills/verification-gate"
  printf '# AGENTS.md\n' > "${dir}/AGENTS.md"
  printf '# replit.md\n' > "${dir}/replit.md"
  printf -- '---\nname: verification-gate\ndescription: d\n---\nbody\n' \
    > "${dir}/.agents/skills/verification-gate/SKILL.md"
}

echo "==> classification"

F="$(claude_only handoff-surface)"
gate_emits "Claude-only surface classified as handoff" "${F}" "handoff" -- run_gate "${F}"

F="$(claude_only active-surface)"; add_replit "${F}"
gate_emits "dual surface classified as active" "${F}" "active" -- run_gate "${F}"

echo "==> incoherent surfaces"

# All three Replit markers must be present or absent together. A partial surface
# means a half-finished handoff, and guessing which way it was headed would either
# resurrect the control plane or delete more of it.
for partial in AGENTS.md replit.md .agents; do
  F="$(claude_only "partial-${partial}")"
  case "$partial" in
    .agents) mkdir -p "${F}/.agents/skills" ;;
    *) printf 'x\n' > "${F}/${partial}" ;;
  esac
  gate_rejects "only ${partial} present" "${F}" \
    "partial Replit surface" -- run_gate "${F}"
done

F="$(claude_only active-without-replit-verification-gate)"
add_replit "${F}"
rm -rf "${F}/.agents/skills/verification-gate"
gate_rejects "active surface missing its Replit verification-gate" "${F}" \
  "active Replit surface is missing verification-gate" -- run_gate "${F}"

echo "==> fail-closed on a broken Claude surface"

F="$(claude_only no-claude-md)"; rm -f "${F}/CLAUDE.md"
gate_rejects "absent CLAUDE.md" "${F}" \
  "required Claude surface is missing: CLAUDE.md" -- run_gate "${F}"

F="$(claude_only no-skills-dir)"; rm -rf "${F}/.claude/skills"
gate_rejects "absent .claude/skills" "${F}" \
  "required Claude surface is missing: .claude/skills" -- run_gate "${F}"

F="$(claude_only no-verification-gate)"
rm -rf "${F}/.claude/skills/verification-gate"
gate_rejects "absent Claude verification-gate" "${F}" \
  "required Claude surface is missing: .claude/skills/verification-gate/SKILL.md" -- run_gate "${F}"

gate_summary "test-gate-agent-surfaces"
