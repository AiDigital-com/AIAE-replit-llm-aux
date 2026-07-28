#!/usr/bin/env bash
# Sync pinned common skills into both native runtime registries atomically.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK_FILE="$REPO_ROOT/llm-aux.lock"
SELECTION_FILE="$REPO_ROOT/.llm-aux-managed-skills"
TARGETS=(claude agents)
MODE="${1:-install}"
case "$MODE" in install|--check|--update-lock) ;; *) echo "usage: $0 [--check|--update-lock]" >&2; exit 2;; esac

fail() { echo "sync-llm-aux: $*" >&2; exit 1; }
require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command '$1' is unavailable"
}
for command_name in ruby git tar find sort uniq awk sed cp mv mktemp; do require_command "$command_name"; done
if command -v shasum >/dev/null 2>&1; then HASH_COMMAND=shasum
elif command -v sha256sum >/dev/null 2>&1; then HASH_COMMAND=sha256sum
else fail "required SHA-256 utility is unavailable (need shasum or sha256sum)"; fi

hash_tree() {
  local dir="$1"
  [ -d "$dir" ] || fail "cannot hash missing directory: $dir"
  (cd "$dir" && find . -type f -print | LC_ALL=C sort | while IFS= read -r file; do
    if [ "$HASH_COMMAND" = shasum ]; then shasum -a 256 "$file"; else sha256sum "$file"; fi
  done) | { if [ "$HASH_COMMAND" = shasum ]; then shasum -a 256; else sha256sum; fi; } | awk '{print $1}'
}
name_of() {
  ruby -ryaml -e 's=STDIN.read; c=s.lines.each_with_index.find{|l,i| i>0 && l.chomp=="---"}; abort "frontmatter missing" unless c; h=YAML.safe_load(s.lines[1...c[1]].join, permitted_classes: [], aliases: false); abort "frontmatter invalid" unless h.is_a?(Hash) && h["name"].is_a?(String); print h["name"]' < "$1"
}
manifest_for() { printf '%s/.%s/.llm-aux-manifest' "$REPO_ROOT" "$1"; }
previous_for() { [ -f "$(manifest_for "$1")" ] && awk -F '\t' '!/^#/ && NF {print $1}' "$(manifest_for "$1")" || true; }
validate_manifest() {
  local target="$1" manifest="$2"
  [ -f "$manifest" ] || return 0
  local line_number=0 seen="" skill row_target source revision path treehash extra
  while IFS=$'\t' read -r skill row_target source revision path treehash extra; do
    line_number=$((line_number + 1))
    case "$skill" in ''|\#*) continue;; esac
    [ -z "${extra:-}" ] \
      || fail "$manifest:$line_number has more than six tab-separated fields"
    case "$skill" in *[!a-z0-9-]*|''|-*|*-) fail "$manifest:$line_number has invalid skill name '$skill'";; esac
    [ "$row_target" = "$target" ] \
      || fail "$manifest:$line_number target '$row_target' must be '$target'"
    case "$source" in
      "AIAE-llm-aux/skills/$skill/SKILL.md"|"AIAE-llm-aux/skills/$skill/SKILL.md.template") ;;
      *) fail "$manifest:$line_number has invalid source '$source' for '$skill'";;
    esac
    printf '%s' "$revision" | grep -Eq '^[0-9a-f]{40,64}$' \
      || fail "$manifest:$line_number has invalid revision '$revision'"
    [ "$path" = ".$target/skills/$skill" ] \
      || fail "$manifest:$line_number path '$path' must be '.$target/skills/$skill'"
    printf '%s' "$treehash" | grep -Eq '^[0-9a-f]{64}$' \
      || fail "$manifest:$line_number has invalid tree hash"
    printf '%s\n' "$seen" | grep -Fxq "$skill" \
      && fail "$manifest:$line_number duplicates skill '$skill'"
    seen="${seen}${skill}"$'\n'
  done < "$manifest"
}
manifest_matches_selection() {
  local target="$1" manifest="$2" desired actual
  desired="$(printf '%s\n' "${SELECTION[@]}" | LC_ALL=C sort)"
  actual="$(awk -F '\t' '!/^#/ && NF {print $1}' "$manifest" | LC_ALL=C sort)"
  [ "$desired" = "$actual" ] \
    || fail "$manifest managed skill set differs from .llm-aux-managed-skills"
}

[ -f "$LOCK_FILE" ] || fail "missing llm-aux.lock"
[ -f "$SELECTION_FILE" ] || fail "missing .llm-aux-managed-skills"
LOCK_REPO="$(awk -F= '$1=="repository" {print substr($0,index($0,"=")+1)}' "$LOCK_FILE")"
LOCK_REV="$(awk -F= '$1=="revision" {print $2}' "$LOCK_FILE")"
[ -n "$LOCK_REPO" ] && [ -n "$LOCK_REV" ] || fail "lock needs repository and revision"
case "$LOCK_REPO" in *://*|git@*) ;; *) fail "lock repository must be a portable URL";; esac
SELECTION=()
while IFS= read -r skill; do case "$skill" in ''|\#*) ;; *) SELECTION+=("$skill");; esac; done < "$SELECTION_FILE"
[ "${#SELECTION[@]}" -gt 0 ] || fail "selection is empty"
for skill in "${SELECTION[@]}"; do
  case "$skill" in *[!a-z0-9-]*|''|-*|*-) fail "invalid selected skill name: '$skill'";; esac
done
duplicate_selection="$(
  printf '%s\n' "${SELECTION[@]}" | LC_ALL=C sort | uniq -d | head -1
)"
[ -z "$duplicate_selection" ] || fail "selection contains duplicate skill '$duplicate_selection'"

SOURCE="${LLM_AUX_SOURCE:-$LOCK_REPO}"
if [ -z "${LLM_AUX_SOURCE:-}" ] && [ -d "$REPO_ROOT/../AIAE-llm-aux/.git" ]; then SOURCE="$REPO_ROOT/../AIAE-llm-aux"; fi
# Git resolves a relative remote URL against the bare cache repository, not
# against the caller's working directory. Canonicalize local overrides before
# storing them as the cache remote so ../AIAE-llm-aux cannot silently resolve to
# an unrelated checkout beside the cache.
case "$SOURCE" in
  *://*|git@*) ;;
  *)
    [ -d "$SOURCE" ] || fail "local common source does not exist: $SOURCE"
    SOURCE="$(cd "$SOURCE" && pwd -P)"
    ;;
esac
CACHE_ROOT="${LLM_AUX_CACHE:-$REPO_ROOT/.llm-aux-cache}"
mkdir -p "$CACHE_ROOT"
CACHE_ROOT="$(cd "$CACHE_ROOT" && pwd -P)"
CACHE="$CACHE_ROOT/AIAE-llm-aux"
CACHE_MARKER="$CACHE/.aiae-llm-aux-cache"

# The cache path is caller-controlled and must never be treated as permission to
# delete a directory. In particular, LLM_AUX_CACHE=<workspace> used to make
# CACHE equal the real sibling AIAE-llm-aux checkout. Reject overlap with a local
# source and any cache that would contain the consumer repository.
case "$SOURCE" in
  *://*|git@*) ;;
  *)
    if [ "$CACHE" = "$SOURCE" ] \
        || [[ "$CACHE" == "$SOURCE/"* ]] \
        || [[ "$SOURCE" == "$CACHE/"* ]]; then
      fail "cache path overlaps the local common source: $CACHE"
    fi
    ;;
esac
if [ "$CACHE" = "$REPO_ROOT" ] || [[ "$REPO_ROOT" == "$CACHE/"* ]]; then
  fail "cache path would contain the consumer repository: $CACHE"
fi

WORK="$(mktemp -d)"
SOURCE_TREE="$WORK/source"
TRANSACTION_ACTIVE=0
rollback() {
  [ "$TRANSACTION_ACTIVE" -eq 1 ] || return 0
  echo "sync-llm-aux: rolling back incomplete transaction" >&2
  for target in "${TARGETS[@]}"; do
    registry="$REPO_ROOT/.$target/skills"; manifest="$(manifest_for "$target")"
    # Remove only directories installed by this transaction, never project-owned files.
    for skill in "${SELECTION[@]}"; do
      if [ -f "$WORK/installed/$target/$skill" ]; then rm -rf "$registry/$skill"; fi
    done
    if [ -d "$WORK/backups/$target/skills" ]; then
      for saved in "$WORK/backups/$target/skills"/*; do
        [ -e "$saved" ] || continue
        mv "$saved" "$registry/$(basename "$saved")"
      done
    fi
    if [ -f "$WORK/backups/$target/manifest-existed" ]; then
      cp "$WORK/backups/$target/manifest" "$manifest"
    elif [ -f "$WORK/manifest-written/$target" ]; then
      rm -f "$manifest"
    fi
  done
  TRANSACTION_ACTIVE=0
}
cleanup() { rollback || true; rm -rf "$WORK"; }
trap cleanup EXIT

# The cache holds objects only — never a working tree. A working-tree cache can
# be left dirty or detached at a commit that upstream later rewrites, and then
# `git checkout` refuses to move and sync wedges permanently. A bare mirror plus
# `git archive` cannot enter that state: nothing is ever checked out, so any
# reachable revision extracts cleanly regardless of what happened before.
if [ -e "$CACHE" ] && [ ! -d "$CACHE" ]; then
  fail "cache path exists and is not a directory: $CACHE"
fi
if [ -d "$CACHE" ]; then
  [ -f "$CACHE_MARKER" ] \
    || fail "refusing to modify unowned cache directory (marker missing): $CACHE"
  grep -qx 'schema=1;owner=AIAE-llm-aux-sync' "$CACHE_MARKER" \
    || fail "cache ownership marker is invalid: $CACHE_MARKER"
  [ "$(git -C "$CACHE" rev-parse --is-bare-repository 2>/dev/null || true)" = "true" ] \
    || fail "refusing to replace unowned/non-bare cache directory: $CACHE"
  git -C "$CACHE" remote set-url origin "$SOURCE"
  git -C "$CACHE" fetch -q --prune origin \
    '+refs/heads/*:refs/heads/*' '+refs/tags/*:refs/tags/*' \
    || fail "cannot fetch from source: $SOURCE"
else
  CACHE_BUILD="$(mktemp -d "$CACHE_ROOT/.aiae-llm-aux-cache.XXXXXX")"
  git clone -q --bare "$SOURCE" "$CACHE_BUILD/repository" \
    || fail "cannot clone source: $SOURCE"
  printf 'schema=1;owner=AIAE-llm-aux-sync\n' \
    > "$CACHE_BUILD/repository/.aiae-llm-aux-cache"
  mv "$CACHE_BUILD/repository" "$CACHE" \
    || fail "cannot install cache at: $CACHE"
  rmdir "$CACHE_BUILD"
fi

if [ "$MODE" = "--update-lock" ]; then
  NEW="$(git -C "$CACHE" rev-parse HEAD)"
  temporary_lock="$(mktemp "${LOCK_FILE}.XXXXXX")"
  sed "s/^revision=.*/revision=$NEW/" "$LOCK_FILE" > "$temporary_lock"
  mv "$temporary_lock" "$LOCK_FILE"
  echo "sync-llm-aux: repinned to $NEW"; exit 0
fi

git -C "$CACHE" cat-file -e "${LOCK_REV}^{commit}" 2>/dev/null \
  || fail "pinned revision not available from ${SOURCE}: $LOCK_REV"
mkdir -p "$SOURCE_TREE"
git -C "$CACHE" archive --format=tar "$LOCK_REV" | tar -x -C "$SOURCE_TREE" \
  || fail "cannot extract pinned revision: $LOCK_REV"
[ -f "$SOURCE_TREE/scripts/render-skills.sh" ] \
  || fail "pinned revision $LOCK_REV has no scripts/render-skills.sh"

# Render and validate all target content before mutating a registry.
for target in "${TARGETS[@]}"; do
  bash "$SOURCE_TREE/scripts/render-skills.sh" --target "$target" --output "$WORK/render/$target" --revision "$LOCK_REV" >/dev/null
  for skill in "${SELECTION[@]}"; do
    [ -d "$WORK/render/$target/$skill" ] || fail "selected skill missing from common source: $skill"
    printf '%s\n' "$(hash_tree "$WORK/render/$target/$skill")" > "$WORK/render/$target/$skill.treehash"
  done
done

# Validate all existing registries before any mutation.
for target in "${TARGETS[@]}"; do
  registry="$REPO_ROOT/.$target/skills"; names=""
  validate_manifest "$target" "$(manifest_for "$target")"
  if [ -d "$registry" ]; then
    while IFS= read -r -d '' file; do
      directory="$(basename "$(dirname "$file")")"; name="$(name_of "$file")" || fail "$file has invalid YAML frontmatter"
      [ "$directory" = "$name" ] || fail "$file directory '$directory' differs from name '$name'"
      printf '%s\n' "$names" | grep -Fxq "$name" && fail "duplicate skill name '$name' in .$target/skills"
      names="${names}${name}"$'\n'
    done < <(find "$registry" -mindepth 2 -maxdepth 2 -name SKILL.md -print0)
  fi
  previous="$(previous_for "$target")"
  for skill in "${SELECTION[@]}"; do
    [ ! -d "$registry/$skill" ] || printf '%s\n' "$previous" | grep -qx "$skill" || fail "collision: .$target/skills/$skill exists outside the managed manifest"
  done
done

if [ "$MODE" = "--check" ]; then
  bad=0
  for target in "${TARGETS[@]}"; do
    registry="$REPO_ROOT/.$target/skills"; manifest="$(manifest_for "$target")"
    [ -f "$manifest" ] || { echo "missing $manifest" >&2; bad=1; continue; }
    manifest_matches_selection "$target" "$manifest"
    for skill in "${SELECTION[@]}"; do
      expected="$(cat "$WORK/render/$target/$skill.treehash")"
      actual="$(hash_tree "$registry/$skill" 2>/dev/null || true)"
      [ "$expected" = "$actual" ] || { echo "drift: .$target/skills/$skill" >&2; bad=1; }
    done
    while IFS=$'\t' read -r skill _ _ revision path treehash; do
      case "$skill" in ''|\#*) continue;; esac
      [ "$revision" = "$LOCK_REV" ] && [ "$(hash_tree "$REPO_ROOT/$path")" = "$treehash" ] || { echo "manifest mismatch: $target/$skill" >&2; bad=1; }
    done < "$manifest"
  done
  [ "$bad" -eq 0 ] || fail "run sync to regenerate managed skills"
  echo "sync-llm-aux: both registries match $LOCK_REV"; exit 0
fi

# Build every planned manifest against staged content before mutation.
for target in "${TARGETS[@]}"; do
  stage="$WORK/stage/$target"; mkdir -p "$stage" "$WORK/manifests"
  for skill in "${SELECTION[@]}"; do cp -R "$WORK/render/$target/$skill" "$stage/$skill"; done
  {
    echo "# Generated by scripts/sync-llm-aux.sh. Do not edit."
    echo "# skill<TAB>target<TAB>source<TAB>revision<TAB>path<TAB>tree-sha256"
    for skill in "${SELECTION[@]}"; do
      source_path="skills/$skill/SKILL.md"; [ -f "$SOURCE_TREE/skills/$skill/SKILL.md.template" ] && source_path="skills/$skill/SKILL.md.template"
      printf '%s\t%s\tAIAE-llm-aux/%s\t%s\t.%s/skills/%s\t%s\n' "$skill" "$target" "$source_path" "$LOCK_REV" "$target" "$skill" "$(cat "$WORK/render/$target/$skill.treehash")"
    done
  } > "$WORK/manifests/$target"
done

# Commit phase. Every old managed directory and manifest is retained until BOTH
# targets have passed post-install hash validation. Any error invokes rollback.
TRANSACTION_ACTIVE=1
for target in "${TARGETS[@]}"; do
  registry="$REPO_ROOT/.$target/skills"; parent="$REPO_ROOT/.$target"; manifest="$(manifest_for "$target")"
  mkdir -p "$registry" "$WORK/backups/$target/skills" "$WORK/installed/$target" "$WORK/manifest-written"
  if [ -f "$manifest" ]; then cp "$manifest" "$WORK/backups/$target/manifest"; : > "$WORK/backups/$target/manifest-existed"; fi
  previous="$(previous_for "$target")"
  for skill in $previous; do [ -n "$skill" ] && [ -d "$registry/$skill" ] && mv "$registry/$skill" "$WORK/backups/$target/skills/$skill"; done
  for skill in "${SELECTION[@]}"; do
    mv "$WORK/stage/$target/$skill" "$registry/$skill"
    : > "$WORK/installed/$target/$skill"
  done
  : > "$WORK/manifest-written/$target"
  cp "$WORK/manifests/$target" "$manifest"
  if [ "${LLM_AUX_FAIL_AFTER_TARGET:-}" = "$target" ]; then fail "fault injection requested after target '$target'"; fi
done

for target in "${TARGETS[@]}"; do
  registry="$REPO_ROOT/.$target/skills"
  for skill in "${SELECTION[@]}"; do
    expected="$(cat "$WORK/render/$target/$skill.treehash")"
    [ "$(hash_tree "$registry/$skill")" = "$expected" ] || fail "post-install tree hash mismatch: .$target/skills/$skill"
  done
done
TRANSACTION_ACTIVE=0
echo "sync-llm-aux: installed ${#SELECTION[@]} common skill(s) into .agents and .claude at $LOCK_REV"
