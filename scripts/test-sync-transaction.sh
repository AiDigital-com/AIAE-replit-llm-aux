#!/usr/bin/env bash
# Regression: a forced failure after the first target must restore BOTH targets.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Match the production resolver: prefer an explicit source, then a sibling
# checkout for offline development, otherwise use the portable URL in the lock.
COMMON="${LLM_AUX_SOURCE:-}"
if [ -z "$COMMON" ] && [ -d "${ROOT}/../AIAE-llm-aux/.git" ]; then
  COMMON="${ROOT}/../AIAE-llm-aux"
fi
if [ -z "$COMMON" ]; then
  COMMON="$(awk -F= '$1=="repository" {print substr($0,index($0,"=")+1)}' "${ROOT}/llm-aux.lock")"
fi
[ -n "$COMMON" ] || {
  echo "test-sync-transaction: no common source in LLM_AUX_SOURCE, sibling checkout, or llm-aux.lock" >&2
  exit 1
}

rsync -a --exclude '.git' --exclude '.llm-aux-cache' "$ROOT/" "$WORK/repo/"

snapshot() {
  local label="$1" repo="$2"
  mkdir -p "$WORK/$label"
  cp -R "$repo/.agents/skills" "$WORK/$label/agents-skills"
  cp -R "$repo/.claude/skills" "$WORK/$label/claude-skills"
  cp "$repo/.agents/.llm-aux-manifest" "$WORK/$label/agents-manifest"
  cp "$repo/.claude/.llm-aux-manifest" "$WORK/$label/claude-manifest"
}

snapshot before "$WORK/repo"

# A relative local override must be resolved before it is stored in the bare
# cache. Otherwise Git interprets it relative to the cache itself and may fetch
# an unrelated repository with the same basename.
if [ -d "$COMMON" ]; then
  COMMON_ABSOLUTE="$(cd "$COMMON" && pwd -P)"
  ln -s "$COMMON_ABSOLUTE" "$WORK/common-relative"
  (
    cd "$WORK"
    LLM_AUX_SOURCE=common-relative \
      LLM_AUX_CACHE="$WORK/relative-cache" \
      bash "$WORK/repo/scripts/sync-llm-aux.sh" --check >/dev/null
  )
  relative_remote="$(
    git -C "$WORK/relative-cache/AIAE-llm-aux" remote get-url origin
  )"
  [ "$relative_remote" = "$COMMON_ABSOLUTE" ] || {
    echo "test-sync-transaction: FAIL — relative source was not canonicalized" >&2
    exit 1
  }
fi

# An existing non-bare directory at the derived cache path is never disposable,
# even when the caller points LLM_AUX_CACHE at it. Preserve a sentinel to guard
# against the former `rm -rf` migration behavior.
mkdir -p "$WORK/cache-guard/AIAE-llm-aux"
printf 'must survive\n' > "$WORK/cache-guard/AIAE-llm-aux/sentinel"
if LLM_AUX_SOURCE="$COMMON" LLM_AUX_CACHE="$WORK/cache-guard" \
    bash "$WORK/repo/scripts/sync-llm-aux.sh" --check >/dev/null 2>&1; then
  echo "test-sync-transaction: FAIL — unowned cache directory was accepted" >&2
  exit 1
fi
grep -qx 'must survive' "$WORK/cache-guard/AIAE-llm-aux/sentinel" || {
  echo "test-sync-transaction: FAIL — unowned cache directory was modified" >&2
  exit 1
}

# Even a valid bare repository is not this script's cache without its explicit
# ownership marker; do not rewrite its remote or refs.
git init -q --bare "$WORK/unowned-bare/AIAE-llm-aux"
if LLM_AUX_SOURCE="$COMMON" LLM_AUX_CACHE="$WORK/unowned-bare" \
    bash "$WORK/repo/scripts/sync-llm-aux.sh" --check >/dev/null 2>&1; then
  echo "test-sync-transaction: FAIL — unowned bare cache was accepted" >&2
  exit 1
fi
test ! -f "$WORK/unowned-bare/AIAE-llm-aux/.aiae-llm-aux-cache"

if LLM_AUX_SOURCE="$COMMON" \
   LLM_AUX_CACHE="$WORK/cache" \
   LLM_AUX_FAIL_AFTER_TARGET=claude \
   bash "$WORK/repo/scripts/sync-llm-aux.sh" >/dev/null 2>&1; then
  echo "test-sync-transaction: FAIL — fault injection unexpectedly succeeded" >&2
  exit 1
fi

diff -rq "$WORK/before/agents-skills" "$WORK/repo/.agents/skills" >/dev/null
diff -rq "$WORK/before/claude-skills" "$WORK/repo/.claude/skills" >/dev/null
diff -q "$WORK/before/agents-manifest" "$WORK/repo/.agents/.llm-aux-manifest" >/dev/null
diff -q "$WORK/before/claude-manifest" "$WORK/repo/.claude/.llm-aux-manifest" >/dev/null

# A manifest is untrusted input until every field is validated. A traversal in
# the skill column previously escaped the registry during the backup/delete
# transaction. Run the adversarial case only inside the disposable fixture.
rsync -a --exclude '.git' --exclude '.llm-aux-cache' "$ROOT/" "$WORK/tampered/"
awk -F '\t' 'BEGIN {OFS="\t"} /^#/ {print; next} !done {$1="../../../templates"; done=1} {print}' \
  "$WORK/tampered/.claude/.llm-aux-manifest" \
  > "$WORK/tampered/.claude/.llm-aux-manifest.tmp"
mv "$WORK/tampered/.claude/.llm-aux-manifest.tmp" \
  "$WORK/tampered/.claude/.llm-aux-manifest"
template_hash_before="$(find "$WORK/tampered/templates" -type f -print | LC_ALL=C sort | xargs shasum | shasum | awk '{print $1}')"
if LLM_AUX_SOURCE="$COMMON" LLM_AUX_CACHE="$WORK/tampered-cache" \
    bash "$WORK/tampered/scripts/sync-llm-aux.sh" >/dev/null 2>&1; then
  echo "test-sync-transaction: FAIL — traversal manifest unexpectedly succeeded" >&2
  exit 1
fi
template_hash_after="$(find "$WORK/tampered/templates" -type f -print | LC_ALL=C sort | xargs shasum | shasum | awk '{print $1}')"
[ "$template_hash_before" = "$template_hash_after" ] \
  || { echo "test-sync-transaction: FAIL — tampered manifest changed templates/" >&2; exit 1; }

# --check must detect a desired selection that was changed without regeneration.
rsync -a --exclude '.git' --exclude '.llm-aux-cache' "$ROOT/" "$WORK/selection-drift/"
grep -v '^task-workflow$' "$WORK/selection-drift/.llm-aux-managed-skills" \
  > "$WORK/selection-drift/.llm-aux-managed-skills.tmp"
mv "$WORK/selection-drift/.llm-aux-managed-skills.tmp" \
  "$WORK/selection-drift/.llm-aux-managed-skills"
if LLM_AUX_SOURCE="$COMMON" LLM_AUX_CACHE="$WORK/selection-cache" \
    bash "$WORK/selection-drift/scripts/sync-llm-aux.sh" --check >/dev/null 2>&1; then
  echo "test-sync-transaction: FAIL — desired-set drift unexpectedly passed" >&2
  exit 1
fi
echo "test-sync-transaction: passed"
