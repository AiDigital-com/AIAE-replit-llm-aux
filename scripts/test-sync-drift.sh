#!/usr/bin/env bash
#
# test-sync-drift.sh — the guard that makes vendoring safe.
#
# Common skills are committed into .claude/skills/ so a downloaded project needs
# no second checkout. The cost of vendoring is that a generated file can be
# hand-edited and silently diverge from its source. This test closes that gap:
# it re-renders from the pinned revision and fails on any difference.
#
# Runs `sync-llm-aux.sh --check`, which writes nothing, then confirms the working
# tree is clean for the paths sync owns.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> test-sync-drift: verifying both skill registries against llm-aux.lock"
if ! bash "${REPO_ROOT}/scripts/sync-llm-aux.sh" --check; then
  cat >&2 <<'EOF'
test-sync-drift: FAIL — generated skills do not match the pinned revision.

A generated skill was edited in place, or llm-aux.lock changed without
regenerating. Generated files are not the source of truth: fix the skill in
AIAE-llm-aux, repin, and regenerate.

  bash scripts/sync-llm-aux.sh
  git add .claude/skills .agents/skills .claude/.llm-aux-manifest .agents/.llm-aux-manifest llm-aux.lock
EOF
  exit 1
fi

# Belt and braces: sync --check compares against a fresh render, but if the repo
# is a git checkout, also confirm nothing sync owns is unstaged, staged, or
# untracked.
if [ -d "${REPO_ROOT}/.git" ]; then
  owned=(
    .claude/.llm-aux-manifest
    .agents/.llm-aux-manifest
    llm-aux.lock
  )
  for manifest in .claude/.llm-aux-manifest .agents/.llm-aux-manifest; do
    while IFS=$'\t' read -r skill target source revision generated_path tree_hash; do
      case "${skill}" in
        ""|\#*) continue ;;
      esac
      owned+=("${generated_path}")
    done < "${REPO_ROOT}/${manifest}"
  done
  if ! git -C "$REPO_ROOT" diff --exit-code -- "${owned[@]}" >/dev/null 2>&1 || \
     ! git -C "$REPO_ROOT" diff --cached --exit-code -- "${owned[@]}" >/dev/null 2>&1 || \
     [ -n "$(git -C "$REPO_ROOT" ls-files --others --exclude-standard -- "${owned[@]}")" ]; then
    echo "test-sync-drift: FAIL — uncommitted changes in sync-owned paths:" >&2
    git -C "$REPO_ROOT" status --short -- "${owned[@]}" >&2 || true
    exit 1
  fi
fi

echo "test-sync-drift: passed"
