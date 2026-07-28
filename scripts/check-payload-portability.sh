#!/usr/bin/env bash
# Validate the active-project payload copied to both native skill registries.
set -euo pipefail
ROOT="${PAYLOAD_PORTABILITY_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PAYLOAD="$ROOT/agent-payload.skills"
failures=0
fail() { echo "check-payload-portability: FAIL — $*" >&2; failures=$((failures+1)); }
skill_name() { ruby -ryaml -e 's=STDIN.read; i=s.lines.each_with_index.find{|l,n|n>0&&l.chomp=="---"}; abort unless i; h=YAML.safe_load(s.lines[1...i[1]].join, permitted_classes: [], aliases: false); print h["name"]' < "$1"; }
[ -f "$PAYLOAD" ] || { echo "missing agent-payload.skills" >&2; exit 1; }

# Fail closed and say why. Without this the file's absence surfaced as a bare
# grep error, which reads like a broken gate rather than a missing input.
[ -f "$ROOT/.llm-aux-managed-skills" ] \
  || { echo "check-payload-portability: missing .llm-aux-managed-skills" >&2; exit 1; }

MANAGED="$(grep -vE '^[[:space:]]*(#|$)' "$ROOT/.llm-aux-managed-skills")"
is_managed() { printf '%s\n' "$MANAGED" | grep -qx "$1"; }

# Validate the template-control-plane state, where both native registries are
# already active. Project-owned skills may cite canonical
# `templates/generated-project/**` documents because those paths exist here;
# materialize-project.sh rewrites the copied registries to
# `.claude/agent_docs/**` and verify-gates validates that installed state.
# Common generated skills must stay template-neutral.
check_references() {
  local dir="$1" label="$2" ref
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    case "$ref" in .claude/tasks/*) continue;; esac   # per-task runtime artifacts
    [ -e "$ROOT/$ref" ] \
      || fail "$label cites a missing template-state path: $ref"
  done < <(
    grep -rhoE \
      '(templates/generated-project|\.claude)/[A-Za-z0-9_./-]+\.(md|sh|ya?ml|json|xml)' \
      "$dir" 2>/dev/null | sort -u
  )
}

while IFS= read -r skill; do
  case "$skill" in ''|\#*) continue;; esac
  for target in claude agents; do
    file="$ROOT/.$target/skills/$skill/SKILL.md"
    [ -f "$file" ] || { fail "$skill missing from .$target/skills"; continue; }
    name="$(skill_name "$file" 2>/dev/null || true)"
    [ "$name" = "$skill" ] || fail "$file directory/frontmatter mismatch"
    if is_managed "$skill" \
        && grep -rqn 'templates/generated-project' "$(dirname "$file")"; then
      fail "common skill $skill in .$target depends on the Replit template tree"
    fi
    check_references "$(dirname "$file")" ".$target/skills/$skill"
  done

  # Both registries must ship the same payload. Project-owned skills are
  # hand-maintained duplicates, so without this check they diverge silently and
  # the two agents follow different instructions in the same repository.
  left="$ROOT/.claude/skills/$skill"; right="$ROOT/.agents/skills/$skill"
  if [ -d "$left" ] && [ -d "$right" ]; then
    if is_managed "$skill"; then
      # Generated copies differ only in the provenance `Target:` line.
      diff -r -I '^Target: ' "$left" "$right" >/dev/null \
        || fail "$skill differs between registries beyond its provenance target"
    else
      diff -r "$left" "$right" >/dev/null \
        || fail "$skill differs between .claude/skills and .agents/skills"
    fi
  fi
done < "$PAYLOAD"

# Common generated copies must have provenance in both targets; project skills
# need not be generated, but must be identical portable payloads.
for skill in $(grep -vE '^[[:space:]]*(#|$)' "$ROOT/.llm-aux-managed-skills"); do
  for target in claude agents; do
    grep -q 'Generated file. Do not edit directly.' "$ROOT/.$target/skills/$skill/SKILL.md" || fail "$skill lacks provenance in .$target"
  done
done

# One canonical source per document. Calculate every digest once; the previous
# nested shell loop re-hashed the installed tree for every canonical document.
# Distillations intentionally differ, so only byte-identical pairs fail.
while IFS= read -r pair; do
  [ -n "$pair" ] || continue
  fail "duplicated document, no single canonical source: $pair"
done < <(
  ruby -rdigest -e '
    root = File.expand_path(ARGV.fetch(0))
    canonical = Dir.glob(File.join(root, "templates/generated-project/**/*.md"))
      .reject { |path| path.include?("/scaffold/") }
    installed = Dir.glob(File.join(root, ".claude/**/*.md"))
    installed_by_hash = installed.group_by do |path|
      Digest::SHA256.file(path).hexdigest
    end
    canonical.each do |source|
      matches = installed_by_hash[Digest::SHA256.file(source).hexdigest] || []
      matches.each do |target|
        puts "#{source.delete_prefix("#{root}/")} == #{target.delete_prefix("#{root}/")}"
      end
    end
  ' "$ROOT"
)

if [ "$failures" -gt 0 ]; then exit 1; fi
echo "check-payload-portability: dual payload is portable, no duplicated documents"
