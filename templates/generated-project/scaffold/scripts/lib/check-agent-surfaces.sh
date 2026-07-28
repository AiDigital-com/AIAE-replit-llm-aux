#!/usr/bin/env bash
# Validate the active dual-agent or post-handoff Claude-only runtime surface.
set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

fail() {
  echo "check-agent-surfaces: $*" >&2
  exit 1
}

for required in \
  CLAUDE.md \
  .claude/skills \
  .claude/skills/verification-gate/SKILL.md; do
  [ -e "$required" ] || fail "required Claude surface is missing: $required"
done

replit_count=0
for path in AGENTS.md replit.md .agents; do
  [ ! -e "$path" ] || replit_count=$((replit_count + 1))
done

case "$replit_count" in
  0)
    printf 'handoff\n'
    ;;
  3)
    [ -f .agents/skills/verification-gate/SKILL.md ] \
      || fail "active Replit surface is missing verification-gate"
    printf 'active\n'
    ;;
  *)
    fail "partial Replit surface: AGENTS.md, replit.md, and .agents must be all present or all absent"
    ;;
esac
