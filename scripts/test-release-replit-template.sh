#!/usr/bin/env bash
# Contract test for release-replit-template.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "${OUT}"' EXIT

for unsafe in \
  / \
  /tmp \
  "$HOME" \
  "$HOME/.." \
  "$REPO_ROOT" \
  "$REPO_ROOT/.." \
  "$REPO_ROOT/templates" \
  "$REPO_ROOT/templates/generated-project/scaffold"; do
  if RELEASE_VALIDATE_DEST_ONLY=1 RELEASE_DEST="$unsafe" \
      bash "${REPO_ROOT}/scripts/release-replit-template.sh" >/dev/null 2>&1; then
    echo "FAIL: unsafe RELEASE_DEST accepted: $unsafe" >&2
    exit 1
  fi
done

RELEASE_DEST="${OUT}/artifact" bash "${REPO_ROOT}/scripts/release-replit-template.sh"

test -f "${OUT}/artifact/backend/pom.xml"
test -f "${OUT}/artifact/.aiae-replit-release"
test -f "${OUT}/artifact/scripts/materialize-project.sh"
test -f "${OUT}/artifact/scripts/replit-env.sh"
test -f "${OUT}/artifact/AGENTS.md"
test -f "${OUT}/artifact/CLAUDE.md"
test -f "${OUT}/artifact/.mcp.json"
grep -q 'https://mcp.context7.com/mcp/oauth' "${OUT}/artifact/.mcp.json"
! grep -Eq 'CONTEXT7_API_KEY|ctx7sk-' "${OUT}/artifact/.mcp.json"
test -f "${OUT}/artifact/AI-DEVELOPMENT-GUIDE.md"
test -f "${OUT}/artifact/agent-payload.skills"
test -f "${OUT}/artifact/.claude/agent_docs/index.md"
test -f "${OUT}/artifact/.claude/agent_docs/project_shape_decision.md"
test -f "${OUT}/artifact/.claude/agent_docs/context7.md"
test -f "${OUT}/artifact/.claude/agent_docs/html_only_project_migration.md"
test -f "${OUT}/artifact/.claude/rules/40-frontend-rules.md"
test -f "${OUT}/artifact/.claude/skills/task-workflow/SKILL.md"
test -f "${OUT}/artifact/.claude/skills/verification-gate/SKILL.md"
test -f "${OUT}/artifact/.claude/skills/verification-gate/agents/openai.yaml"
test -f "${OUT}/artifact/.claude/agent_docs/skill-selection.md"
# Both agent entry points and discovery registries are present.
test -f "${OUT}/artifact/AGENTS.md"
test -f "${OUT}/artifact/replit.md"
test -f "${OUT}/artifact/scripts/prepare-engineering-handoff.sh"

test -f "${OUT}/artifact/.agents/skills/task-workflow/SKILL.md"
test -f "${OUT}/artifact/.agents/skills/verification-gate/SKILL.md"
test -f "${OUT}/artifact/.agents/skills/verification-gate/agents/openai.yaml"

# Repeated release owns and may replace its prior output.
RELEASE_DEST="${OUT}/artifact" bash "${REPO_ROOT}/scripts/release-replit-template.sh" >/dev/null

# A path-safe but unowned non-empty destination must never be deleted.
mkdir -p "${OUT}/unowned"
printf 'keep me\n' > "${OUT}/unowned/notes.txt"
if RELEASE_DEST="${OUT}/unowned" \
    bash "${REPO_ROOT}/scripts/release-replit-template.sh" >/dev/null 2>&1; then
  echo "FAIL: release accepted a non-empty unowned destination"
  exit 1
fi
grep -q 'keep me' "${OUT}/unowned/notes.txt"

# Payload skills resolve without templates/, which the artifact does not ship.
if grep -rqn "templates/generated-project" "${OUT}/artifact/.claude/skills" "${OUT}/artifact/.agents/skills" 2>/dev/null; then
  echo "FAIL: artifact ships a skill referencing templates/generated-project"
  grep -rn "templates/generated-project" "${OUT}/artifact/.claude/skills" "${OUT}/artifact/.agents/skills"
  exit 1
fi

# Replit-specific portable workflows must ship in both registries.
for runtime_skill in backend-java-feature frontend-react-feature openapi-contract-first mvp-safety-review engineering-handoff finalize-coverage; do
  test -f "${OUT}/artifact/.claude/skills/${runtime_skill}/SKILL.md"
  test -f "${OUT}/artifact/.agents/skills/${runtime_skill}/SKILL.md"
done
# No template control-plane leakage.
! test -d "${OUT}/artifact/templates/generated-project/scaffold" \
  || { echo "FAIL: release artifact embeds control-plane scaffold"; exit 1; }
! test -d "${OUT}/artifact/custom_instruction" \
  || { echo "FAIL: release artifact contains custom_instruction"; exit 1; }
echo "test-release-replit-template: passed"
