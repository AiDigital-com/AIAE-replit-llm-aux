#!/usr/bin/env bash
#
# new-project.sh — create a new project from this template WITHOUT Replit.
#
# The Replit path (fork the template, `.replit` onBoot runs setup-project.sh) is
# one entry point, not the only one. This script is the local/Claude Code entry
# point: from a plain clone of this repository, scaffold a fresh project into any
# directory, with the full engineering surface installed.
#
# What you get in <target-dir>:
#   backend/ frontend/ scripts/ docker-compose.yml .env.example  — the app
#   CLAUDE.md .claude/rules .claude/agent_docs .claude/skills .claude/tasks — rules + skills
#   AGENTS.md replit.md .agents/skills                           — unless --claude-only
#
# The target is a self-contained repository. It does not reference this template
# at runtime, so it works after `git clone` on any machine.
#
# Usage:
#   bash scripts/new-project.sh <target-dir> <app-name-package> [options]
#
# Options:
#   --claude-only   Drop Replit control-plane files (AGENTS.md, replit.md, .agents).
#                   Use when the project will never be developed on Replit.
#   --no-git        Do not `git init` the target directory.
#   --no-commit      Leave the target with no Git repository at all.
#
# A scaffolded project gets an initial commit by default. That is not a courtesy:
# git-commit-id-maven-plugin cannot resolve HEAD in a repo with zero commits, so
# `git init` without a commit produced a project whose very first `mvn verify` failed
# with "Could not get HEAD Ref". Either state is fine — a repo with a commit, or no
# repo — but never the broken middle one, so --no-commit skips `git init` too.
#   --force         Proceed even if the target directory is non-empty.
#
# Examples:
#   bash scripts/new-project.sh ~/work/margin-tool margintool
#   bash scripts/new-project.sh ~/work/margin-tool margintool --claude-only
#
# <app-name-package> becomes the Java package suffix: com.aidigital.<name>.*
# It must be lowercase letters and digits only (no dots, dashes, underscores).

set -euo pipefail

TEMPLATE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCAFFOLD="${TEMPLATE_ROOT}/templates/generated-project/scaffold"

CLAUDE_ONLY=0
DO_GIT=1
DO_COMMIT=1
FORCE=0
TARGET=""
APP_NAME=""

usage() {
  sed -n '3,32p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-2}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --claude-only) CLAUDE_ONLY=1; shift ;;
    --no-git)      DO_GIT=0; shift ;;
    --commit)      DO_COMMIT=1; shift ;;
    --no-commit)   DO_COMMIT=0; DO_GIT=0; shift ;;
    --force)       FORCE=1; shift ;;
    -h|--help)     usage 0 ;;
    -*) echo "new-project: unknown option: $1" >&2; usage ;;
    *)
      if [ -z "$TARGET" ]; then TARGET="$1"
      elif [ -z "$APP_NAME" ]; then APP_NAME="$1"
      else echo "new-project: unexpected argument: $1" >&2; usage
      fi
      shift ;;
  esac
done

fail() { echo "new-project: $*" >&2; exit 1; }

[ -n "$TARGET" ]   || { echo "new-project: <target-dir> is required" >&2; usage; }
[ -n "$APP_NAME" ] || { echo "new-project: <app-name-package> is required" >&2; usage; }

# The package suffix ends up in Java package declarations, so validate it here
# rather than letting javac fail hundreds of files later.
case "$APP_NAME" in
  *[^a-z0-9]*) fail "app-name-package '${APP_NAME}' must be lowercase letters and digits only" ;;
esac

[ -d "$SCAFFOLD" ] || fail "scaffold not found at ${SCAFFOLD} — run this from a clone of the template repo"
[ -f "${TEMPLATE_ROOT}/CLAUDE.md" ] || fail "CLAUDE.md not found in ${TEMPLATE_ROOT}"
[ -f "${TEMPLATE_ROOT}/agent-payload.skills" ] || fail "agent-payload.skills not found in ${TEMPLATE_ROOT}"

mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"

if [ "$TARGET" = "$TEMPLATE_ROOT" ]; then
  fail "target must not be the template repository itself"
fi

if [ "$FORCE" -eq 0 ] && [ -n "$(ls -A "$TARGET" 2>/dev/null)" ]; then
  fail "target ${TARGET} is not empty — pass --force to scaffold into it anyway"
fi

echo "==> new-project: template ${TEMPLATE_ROOT}"
echo "==> new-project: target   ${TARGET}"
echo "==> new-project: package  com.aidigital.${APP_NAME}"

# Verify the template is internally consistent before copying anything out of
# it. A broken payload contract would otherwise be baked into the new project.
bash "${TEMPLATE_ROOT}/scripts/check-payload-portability.sh" >/dev/null \
  || fail "template payload check failed — run: bash scripts/check-payload-portability.sh"

# materialize-project.sh is the single implementation of "copy the scaffold and
# install the engineering surface". Reuse it; do not duplicate the copy logic.
MATERIALIZE_DEST="$TARGET" \
SCAFFOLD_ROOT="$SCAFFOLD" \
TEMPLATE_REPO_ROOT="$TEMPLATE_ROOT" \
  bash "${SCAFFOLD}/scripts/materialize-project.sh" "$APP_NAME"

if [ "$CLAUDE_ONLY" -eq 1 ]; then
  echo "==> new-project: removing Replit agent entry points (--claude-only)"
  rm -f "${TARGET}/AGENTS.md" "${TARGET}/replit.md"
  rm -rf "${TARGET}/.agents"
fi

if [ "$DO_GIT" -eq 1 ] && [ ! -d "${TARGET}/.git" ]; then
  echo "==> new-project: git init"
  git -C "$TARGET" init -q
fi
if [ "$DO_COMMIT" -eq 1 ]; then
  [ "$DO_GIT" -eq 1 ] || fail "--commit requires git; remove --no-git"
  if [ ! -d "${TARGET}/.git" ]; then git -C "$TARGET" init -q; fi
  echo "==> new-project: creating requested initial commit"
  git -C "$TARGET" add -A
  if ! git -C "$TARGET" commit -q -m "Scaffold ${APP_NAME} from AIAE template" 2>/dev/null; then
    if ! git -C "$TARGET" \
        -c user.name="AIAE Template" \
        -c user.email="template@aidigital.local" \
        commit -q -m "Scaffold ${APP_NAME} from AIAE template" 2>/dev/null; then
      echo "==> WARNING: could not create the initial commit." >&2
      echo "    Commit it manually after configuring your Git identity." >&2
      echo "    Run: git -C ${TARGET} add -A && git -C ${TARGET} commit -m 'Initial scaffold'" >&2
    fi
  fi
fi

# Post-checks: the new project must stand on its own.
[ -f "${TARGET}/CLAUDE.md" ]                 || fail "CLAUDE.md was not installed"
[ -d "${TARGET}/.claude/rules" ]             || fail ".claude/rules was not installed"
[ -d "${TARGET}/.claude/skills" ]            || fail ".claude/skills was not installed"
[ -f "${TARGET}/.claude/tasks/README.md" ]   || fail ".claude/tasks was not installed"
[ -f "${TARGET}/backend/pom.xml" ]           || fail "backend was not scaffolded"
[ -d "${TARGET}/frontend" ]                  || fail "frontend was not scaffolded"
if [ "$CLAUDE_ONLY" -eq 1 ]; then
  [ ! -d "${TARGET}/.agents" ] || fail ".agents must be absent with --claude-only"
else
  [ -d "${TARGET}/.agents/skills" ] || fail ".agents/skills was not installed"
fi

# Self-containment: nothing in the installed surface may point back at the
# template's own tree, or the new project breaks the moment it is moved.
if grep -rqn "templates/generated-project" "${TARGET}/.claude" "${TARGET}/.agents" "${TARGET}/CLAUDE.md" 2>/dev/null; then
  echo "new-project: the installed surface references the template tree:" >&2
  grep -rn "templates/generated-project" "${TARGET}/.claude" "${TARGET}/.agents" "${TARGET}/CLAUDE.md" >&2
  fail "new project is not self-contained"
fi

skill_count="$(find "${TARGET}/.claude/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"

cat <<EOF

==> new-project: done

    ${TARGET}
      backend/  frontend/  scripts/     the app (package com.aidigital.${APP_NAME})
      CLAUDE.md .claude/               rules, agent docs, ${skill_count} skills, task artifacts
$([ "$CLAUDE_ONLY" -eq 0 ] && echo "      AGENTS.md replit.md .agents/    Replit entry points and discovered skills")

    Next:
      cd ${TARGET}
      claude                                  # picks up CLAUDE.md + .claude/ automatically
      bash scripts/strip-scaffold-samples.sh   # remove the sample aggregate before real work
      bash scripts/local-verify.sh             # structure lint + verify gates
      docker compose --profile local up --build

    The project is self-contained: it does not need this template checkout again.
EOF
