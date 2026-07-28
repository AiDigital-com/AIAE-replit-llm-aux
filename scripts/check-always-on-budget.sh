#!/usr/bin/env bash
# check-always-on-budget.sh — cap the context every task pays for unconditionally.
#
# Claude Code loads CLAUDE.md and every `.claude/rules/*.md` whose frontmatter has
# no `paths:` into every single task, whatever the task is. That cost is invisible
# in review: adding twenty lines to an always-on rule looks like a twenty-line
# diff, not like a permanent tax on every future request.
#
# The budget makes the tax explicit. Exceeding it is not forbidden — it requires
# raising the number here, which is a visible, reviewable decision.
#
# Path-scoped rules are deliberately not counted: they load only when a matching
# file is touched, which is the mechanism that keeps the always-on set small.
#
# History: `.claude/rules/README.md` sat here at 320 words — 22% of the entire
# always-on budget — documenting the rule-loading convention for maintainers, not
# instructing the agent. It moved to `.claude/agent_docs/rule-loading-conventions.md`.
# A fake never-matching `paths:` would have hidden it from this check while still
# shipping it; moving it out was the honest fix.
set -euo pipefail

ROOT="${ALWAYS_ON_BUDGET_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Ceiling in words. Set from the measured, reviewed size (1127 words) plus roughly
# a quarter for normal growth. Raise it deliberately, in a commit that says why.
BUDGET_WORDS="${ALWAYS_ON_BUDGET_WORDS:-1400}"

fail() { echo "check-always-on-budget: FAIL — $*" >&2; }

[ -d "$ROOT/.claude/rules" ] \
  || { echo "check-always-on-budget: no .claude/rules in ${ROOT}" >&2; exit 1; }
[ -f "$ROOT/CLAUDE.md" ] \
  || { echo "check-always-on-budget: no CLAUDE.md in ${ROOT}" >&2; exit 1; }

# A rule is always-on when its frontmatter declares no `paths:`. Read only the
# frontmatter block, so a `paths:` mentioned in prose cannot exempt a file.
has_paths() {
  local file="$1"
  [ "$(head -1 "$file")" = "---" ] || return 1
  awk 'NR==1{next} /^---$/{exit} /^paths:/{found=1} END{exit !found}' "$file"
}

total=0
declare -a counted=()

add() {
  local file="$1" words
  words="$(wc -w < "$file" | tr -d ' ')"
  total=$((total + words))
  counted+=("$(printf '%6s  %s' "$words" "${file#"$ROOT"/}")")
}

add "$ROOT/CLAUDE.md"
while IFS= read -r rule; do
  has_paths "$rule" && continue
  add "$rule"
done < <(find "$ROOT/.claude/rules" -maxdepth 1 -type f -name '*.md' | LC_ALL=C sort)

echo "check-always-on-budget: always-on context in ${ROOT#"$PWD"/}"
printf '%s\n' "${counted[@]}" | sed 's/^/  /'
printf '  %6s  TOTAL (budget %s)\n' "$total" "$BUDGET_WORDS"

if [ "$total" -gt "$BUDGET_WORDS" ]; then
  fail "always-on context is ${total} words, over the ${BUDGET_WORDS}-word budget by $((total - BUDGET_WORDS))."
  echo "       Every task pays this, including tasks the added text is irrelevant to." >&2
  echo "       Prefer one of, in order:" >&2
  echo "         - give the rule a 'paths:' glob so it loads only where it applies;" >&2
  echo "         - move background or maintainer documentation to .claude/agent_docs/;" >&2
  echo "         - tighten the wording;" >&2
  echo "         - raise BUDGET_WORDS in this script, in a commit that says why." >&2
  exit 1
fi

echo "check-always-on-budget: within budget"
