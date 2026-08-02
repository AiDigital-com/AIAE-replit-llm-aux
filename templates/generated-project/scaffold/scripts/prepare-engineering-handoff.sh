#!/usr/bin/env bash
#
# prepare-engineering-handoff.sh — strip Replit control-plane artifacts from a
# generated project, producing a clean engineering/customer repository.
#
# Removes:
#   AGENTS.md
#   replit.md
#   .agents/
#   custom_instruction/
#   templates/
#
# Preserves:
#   CLAUDE.md
#   .claude/          — rules, agent docs, skills, and task artifacts all survive
#   application source, except explicitly reserved scaffold-only feature
#   templates under frontend/src/features/_template[s]
#
# Also removes the MVP-only event-logging-to-db feature, its safe @LogUsage
# call sites, configuration, and Liquibase migration before final validation.
#
# This is a one-way transformation, so it is opt-in rather than opt-out: without
# --apply it prints what it would remove and exits 0. It also refuses to run on a
# dirty git tree, so the deletion is always recoverable via git.
#
# Usage:
#   bash scripts/prepare-engineering-handoff.sh                     # dry run
#   bash scripts/prepare-engineering-handoff.sh --apply             # do it
#   bash scripts/prepare-engineering-handoff.sh --target <dir> --apply
#
# Environment:
#   HANDOFF_TARGET — target directory (default: parent of scripts/)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${HANDOFF_TARGET:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
APPLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:?--target requires a directory path}"; shift 2 ;;
    --apply)  APPLY=1; shift ;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "prepare-engineering-handoff: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ ! -d "$TARGET" ]; then
  echo "prepare-engineering-handoff: target directory does not exist: ${TARGET}" >&2
  exit 1
fi

cd "$TARGET"

CONTROL_PLANE=(
  AGENTS.md
  replit.md
  .agents
  custom_instruction
  templates
)

PRESERVE=(
  CLAUDE.md
  .claude
)

FRONTEND_TEMPLATE_DIRS=(
  frontend/src/features/_template
  frontend/src/features/_templates
)

# Refuse before deleting anything if the required Claude engineering surface is
# already incomplete. Post-delete validation remains as defense in depth.
for required in CLAUDE.md .claude .claude/skills .claude/rules .claude/agent_docs; do
  [ -e "$required" ] || {
    echo "prepare-engineering-handoff: BLOCKED — required Claude surface is missing: $required" >&2
    exit 1
  }
done

# Refuse to destroy uncommitted work. There is deliberately no override: a
# handoff is a reviewable deletion commit and must remain recoverable.
if [ "$APPLY" -eq 1 ]; then
  if git rev-parse --git-dir >/dev/null 2>&1; then
    if ! git diff --quiet HEAD 2>/dev/null || [ -n "$(git status --porcelain 2>/dev/null)" ]; then
      cat >&2 <<EOF
prepare-engineering-handoff: refusing to run — the git tree is not clean.

This permanently removes files. Commit or stash first so the removal is a
reviewable diff you can revert:

  git add -A && git commit -m "pre-handoff checkpoint"
  bash scripts/prepare-engineering-handoff.sh --apply
EOF
      exit 1
    fi
  else
    cat >&2 <<EOF
prepare-engineering-handoff: refusing to run — ${TARGET} is not a git repository,
so this removal would be unrecoverable. Initialize git and commit the project first.
EOF
    exit 1
  fi
fi

# Coverage finalization is the required last step. All verification helpers are
# mandatory; missing one is a blocker rather than a reason to fail open.
REQUIRED_VERIFICATION_FILES=(
  scripts/local-verify.sh
  scripts/structure-lint.sh
  scripts/verify-gates.sh
  scripts/remove-usage-logging.sh
  scripts/lib/remove-usage-logging.py
  scripts/lib/liquibase_dependency_guard.py
  scripts/lib/coverage-phase.sh
  scripts/lib/check-coverage-integrity.sh
  scripts/lib/check-architecture-overview.sh
)
for required in "${REQUIRED_VERIFICATION_FILES[@]}"; do
  [ -f "$required" ] || {
    echo "prepare-engineering-handoff: BLOCKED — required verification file is missing: $required" >&2
    exit 1
  }
done

# shellcheck source=./lib/coverage-phase.sh
. scripts/lib/coverage-phase.sh
HANDOFF_PHASE="$(coverage_phase_read .)" || exit 1
if [ "$HANDOFF_PHASE" = "mvp" ]; then
    cat >&2 <<EOF
prepare-engineering-handoff: BLOCKED — coverage has not been finalized.

${COVERAGE_PHASE_FILE} still reads 'mvp', so the build is running against the
relaxed floor (${COVERAGE_MVP_LINE_MIN} line / ${COVERAGE_MVP_BRANCH_MIN} branch).
A project cannot be handed to engineering on the MVP gate.

Finish the required last step:

  1. Raise coverage to ${COVERAGE_STRICT_LINE_MIN} line / ${COVERAGE_STRICT_BRANCH_MIN} branch.
     Ask Claude Code: "finalize coverage"
  2. echo engineering > ${COVERAGE_PHASE_FILE}
  3. bash scripts/local-verify.sh      # must pass on the strict gate
  4. re-run this script

There is no flag to skip this. Lowering the thresholds instead is rejected by
scripts/lib/check-coverage-integrity.sh.
EOF
  exit 1
fi
VERIFY_ROOT="$TARGET" bash scripts/lib/check-coverage-integrity.sh
VERIFY_ROOT="$TARGET" bash scripts/lib/check-architecture-overview.sh

validate_usage_telemetry_architecture() {
  local doc="docs/architecture-overview.md"

  [ "$(grep -Fxc -- '- MVP usage telemetry: enabled during MVP' "${doc}")" -eq 1 ] \
    || { echo "prepare-engineering-handoff: expected one active MVP telemetry status in ${doc}" >&2; return 1; }
  [ "$(grep -Fc '| `backend/event-logging-to-db-feature` |' "${doc}")" -eq 1 ] \
    || { echo "prepare-engineering-handoff: expected the managed MVP telemetry module row in ${doc}" >&2; return 1; }
}

# Usage logging is part of the MVP testing/feedback phase, not the engineering
# handoff baseline. Validate the transformation during dry-run. On apply,
# perform it before local verification so the exact handed-off application —
# not the pre-cleanup variant — is what passes the strict build.
if [ -d backend/event-logging-to-db-feature ]; then
  validate_usage_telemetry_architecture
  if [ "$APPLY" -eq 1 ]; then
    echo "==> Removing MVP usage logging before engineering verification"
    bash scripts/remove-usage-logging.sh --apply
  else
    bash scripts/remove-usage-logging.sh
  fi
fi

# The copyable frontend feature is teaching material, not product source. Never
# remove it while application code still imports it: doing so would make the
# post-handoff tree fail only after the last verification. A real first feature
# must replace the scaffold import before handoff.
for template_dir in "${FRONTEND_TEMPLATE_DIRS[@]}"; do
  if [ ! -d "$template_dir" ]; then
    continue
  fi
  if find frontend/src -type f \
      ! -path "${template_dir}/*" \
      \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.css' \) \
      -exec grep -El 'features/_templates?|\./_templates?|\.\./_templates?|TemplateProfilePanel' {} + \
      2>/dev/null | grep -q .; then
    cat >&2 <<EOF
prepare-engineering-handoff: BLOCKED — application code still references ${template_dir}.

Replace the scaffold TemplateProfilePanel with real product features, remove
its imports/routes/styles, verify the frontend, then re-run handoff.
EOF
    exit 1
  fi
  if [ "$APPLY" -eq 1 ]; then
    rm -rf "$template_dir"
    echo "==> removed scaffold-only ${template_dir}"
  else
    echo "prepare-engineering-handoff: validated removal of ${template_dir}"
  fi
done

# A marker flip or caller-written file is not verification. Execute the fixed
# project-local verification command synchronously immediately before deletion.
# This covers the strict backend build, frontend checks, policy gates, and
# compose validation against the exact clean tree being handed off.
if [ "$APPLY" -eq 1 ]; then
  echo "==> Running mandatory engineering verification before cleanup"
  bash scripts/local-verify.sh
fi

echo "==> prepare-engineering-handoff: target ${TARGET}"

if [ "$APPLY" -eq 0 ]; then
  echo "==> DRY RUN — nothing will be removed. Re-run with --apply to proceed."
  echo
  echo "    Would remove:"
  found=0
  for path in "${CONTROL_PLANE[@]}"; do
    if [ -e "$path" ]; then
      if [ -d "$path" ]; then
        echo "      ${path}/  ($(find "$path" -type f | wc -l | tr -d ' ') files)"
      else
        echo "      ${path}"
      fi
      found=$((found + 1))
    fi
  done
  [ "$found" -gt 0 ] || echo "      (nothing — already handed off)"
  echo
  echo "    Would preserve:"
  for path in "${PRESERVE[@]}"; do
    if [ -e "$path" ]; then
      echo "      ${path}"
    else
      echo "      ${path}  — MISSING, expected to be present" >&2
    fi
  done
  echo
  echo "==> prepare-engineering-handoff: dry run complete"
  exit 0
fi

REMOVED=0
for path in "${CONTROL_PLANE[@]}"; do
  if [ -e "$path" ]; then
    rm -rf "$path"
    echo "==> removed ${path}"
    REMOVED=$((REMOVED + 1))
  fi
done

PRESERVED=0
for path in "${PRESERVE[@]}"; do
  if [ -e "$path" ]; then
    echo "==> preserved ${path}"
    PRESERVED=$((PRESERVED + 1))
  else
    echo "==> WARNING: expected ${path} but it is absent" >&2
  fi
done

# Validate: no control-plane leakage.
for leak in "${CONTROL_PLANE[@]}"; do
  if [ -e "$leak" ]; then
    echo "prepare-engineering-handoff: FAILED — ${leak} still present after cleanup" >&2
    exit 1
  fi
done

# Validate: the Claude surface is intact and self-contained.
[ -f CLAUDE.md ] || { echo "prepare-engineering-handoff: FAILED — CLAUDE.md missing" >&2; exit 1; }
[ -d .claude ]   || { echo "prepare-engineering-handoff: FAILED — .claude/ missing" >&2; exit 1; }
[ -d .claude/skills ] || { echo "prepare-engineering-handoff: FAILED — .claude/skills missing" >&2; exit 1; }
[ -d .claude/rules ]  || { echo "prepare-engineering-handoff: FAILED — .claude/rules missing" >&2; exit 1; }
[ ! -d backend/event-logging-to-db-feature ] \
  || { echo "prepare-engineering-handoff: FAILED — MVP usage-logging module remains" >&2; exit 1; }
[ ! -f backend/migrations/src/main/resources/db/changelog/changes/0001-usage-events.xml ] \
  || { echo "prepare-engineering-handoff: FAILED — usage-events migration remains" >&2; exit 1; }
for template_dir in "${FRONTEND_TEMPLATE_DIRS[@]}"; do
  [ ! -e "$template_dir" ] \
    || { echo "prepare-engineering-handoff: FAILED — scaffold-only ${template_dir} remains" >&2; exit 1; }
done
if find backend -type f -name '*.java' ! -path '*/target/*' \
    -exec grep -Eq '@LogUsage|UsageAttributes|\.usagelogging\.' {} \; \
    -print -quit | grep -q .; then
  echo "prepare-engineering-handoff: FAILED — usage-logging Java call sites remain" >&2
  exit 1
fi
bash scripts/lib/check-agent-surfaces.sh . | grep -qx handoff \
  || { echo "prepare-engineering-handoff: FAILED — invalid post-handoff agent surface" >&2; exit 1; }
VERIFY_ROOT="$TARGET" bash scripts/verify-gates.sh

echo "==> prepare-engineering-handoff: done — removed ${REMOVED}, preserved ${PRESERVED}"
echo "==> the repository is ready for engineering/customer transfer"
