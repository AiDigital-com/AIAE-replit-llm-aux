#!/usr/bin/env bash
# Verify the compatibility installer produces a self-contained Claude surface.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$(mktemp -d)"
WORK="$(mktemp -d)"
trap 'rm -rf "${TARGET}" "${WORK}"' EXIT

cat > "${TARGET}/.mcp.json" <<'EOF'
{
  "mcpServers": {
    "other": {
      "type": "http",
      "url": "https://example.invalid/mcp"
    }
  }
}
EOF

bash "${ROOT}/scripts/install-claude-fixtures.sh" "${TARGET}" >/dev/null

test -f "${TARGET}/CLAUDE.md"
test -f "${TARGET}/.claude/skills/backend-java-feature/SKILL.md"
test -f "${TARGET}/.claude/skills/verification-gate/agents/openai.yaml"
grep -Fq '## Step 5 — Independent final review convergence' \
  "${TARGET}/.claude/skills/task-workflow/SKILL.md"
test -f "${TARGET}/.claude/agent_docs/openapi/canonical-openapi-rules.md"
test -f "${TARGET}/.claude/agent_docs/testing/testing-policy.md"
test -f "${TARGET}/.claude/.aiae-fixtures-manifest"
test -f "${TARGET}/agent-payload.skills"
test -f "${TARGET}/.claude/skills/local-preview/SKILL.md"
test -f "${TARGET}/.claude/agent_docs/agent-operating-model.md"
grep -q 'https://mcp.context7.com/mcp/oauth' "${TARGET}/.mcp.json"
grep -q 'https://example.invalid/mcp' "${TARGET}/.mcp.json"
test ! -d "${TARGET}/.claude/skills/project-init"
grep -q '\.claude/agent_docs/openapi/canonical-openapi-rules.md' \
  "${TARGET}/.claude/skills/backend-java-feature/SKILL.md"
if grep -rqn 'templates/generated-project' "${TARGET}/.claude"; then
  echo "test-install-claude-fixtures: control-plane reference survived installation" >&2
  exit 1
fi
python3 \
  "${ROOT}/templates/generated-project/scaffold/scripts/lib/check-installed-documentation-links.py" \
  "${TARGET}" >/dev/null

# Reinstall is deterministic and keeps unrelated MCP servers.
before_hash="$(shasum -a 256 "${TARGET}/.claude/.aiae-fixtures-manifest" | awk '{print $1}')"
bash "${ROOT}/scripts/install-claude-fixtures.sh" "${TARGET}" >/dev/null
after_hash="$(shasum -a 256 "${TARGET}/.claude/.aiae-fixtures-manifest" | awk '{print $1}')"
[ "${before_hash}" = "${after_hash}" ]
grep -q 'https://example.invalid/mcp' "${TARGET}/.mcp.json"

# A tampered ownership manifest must not turn arbitrary project files into
# deletable fixture content.
TAMPERED="${WORK}/tampered-manifest"
mkdir -p "${TAMPERED}/.git"
printf 'important project config\n' > "${TAMPERED}/.git/config"
bash "${ROOT}/scripts/install-claude-fixtures.sh" "${TAMPERED}" >/dev/null
config_hash="$(shasum -a 256 "${TAMPERED}/.git/config" | awk '{print $1}')"
printf '.git/config\t%s\n' "${config_hash}" \
  >> "${TAMPERED}/.claude/.aiae-fixtures-manifest"
if bash "${ROOT}/scripts/install-claude-fixtures.sh" "${TAMPERED}" >/dev/null 2>&1; then
  echo "test-install-claude-fixtures: unsafe manifest namespace was accepted" >&2
  exit 1
fi
grep -qx 'important project config' "${TAMPERED}/.git/config"

# Existing symlinked ancestors may not redirect fixture writes outside target.
SYMLINKED="${WORK}/symlinked-target"
OUTSIDE="${WORK}/outside-target"
mkdir -p "${SYMLINKED}/.claude" "${OUTSIDE}"
ln -s "${OUTSIDE}" "${SYMLINKED}/.claude/agent_docs"
if bash "${ROOT}/scripts/install-claude-fixtures.sh" "${SYMLINKED}" >/dev/null 2>&1; then
  echo "test-install-claude-fixtures: symlinked fixture ancestor was accepted" >&2
  exit 1
fi
test -z "$(find "${OUTSIDE}" -mindepth 1 -print -quit)"

# A symlink that stays inside the project is equally unsafe: a tampered
# manifest must not claim and delete an application file through it.
IN_PROJECT_LINK="${WORK}/in-project-link"
mkdir -p "${IN_PROJECT_LINK}/backend"
bash "${ROOT}/scripts/install-claude-fixtures.sh" "${IN_PROJECT_LINK}" >/dev/null
printf 'application source must survive\n' \
  > "${IN_PROJECT_LINK}/backend/protected.txt"
ln -s ../../backend "${IN_PROJECT_LINK}/.claude/skills/obsolete"
protected_hash="$(
  shasum -a 256 "${IN_PROJECT_LINK}/backend/protected.txt" | awk '{print $1}'
)"
printf '.claude/skills/obsolete/protected.txt\t%s\n' "${protected_hash}" \
  >> "${IN_PROJECT_LINK}/.claude/.aiae-fixtures-manifest"
if bash "${ROOT}/scripts/install-claude-fixtures.sh" "${IN_PROJECT_LINK}" >/dev/null 2>&1; then
  echo "test-install-claude-fixtures: in-project symlink was accepted" >&2
  exit 1
fi
grep -qx 'application source must survive' \
  "${IN_PROJECT_LINK}/backend/protected.txt"

# The ownership manifest is also a write target and may not be redirected out
# of the project by a symlink.
MANIFEST_LINK="${WORK}/manifest-link"
EXTERNAL_MANIFEST="${WORK}/external-manifest"
mkdir -p "${MANIFEST_LINK}/.claude"
printf 'external file must survive\n' > "${EXTERNAL_MANIFEST}"
ln -s "${EXTERNAL_MANIFEST}" \
  "${MANIFEST_LINK}/.claude/.aiae-fixtures-manifest"
if bash "${ROOT}/scripts/install-claude-fixtures.sh" "${MANIFEST_LINK}" >/dev/null 2>&1; then
  echo "test-install-claude-fixtures: symlinked ownership manifest was accepted" >&2
  exit 1
fi
grep -qx 'external file must survive' "${EXTERNAL_MANIFEST}"

# A removed payload skill is deleted only when its files were owned by the prior
# fixture manifest.
rsync -a --exclude '.git' --exclude '.llm-aux-cache' "${ROOT}/" "${WORK}/source/"
grep -v '^ui-designer$' "${WORK}/source/agent-payload.skills" \
  > "${WORK}/source/agent-payload.skills.tmp"
mv "${WORK}/source/agent-payload.skills.tmp" "${WORK}/source/agent-payload.skills"
bash "${WORK}/source/scripts/install-claude-fixtures.sh" "${TARGET}" >/dev/null
test ! -f "${TARGET}/.claude/skills/ui-designer/SKILL.md"

# Local edits to an owned root contract block the next install.
printf '\nlocal edit\n' >> "${TARGET}/CLAUDE.md"
if bash "${WORK}/source/scripts/install-claude-fixtures.sh" "${TARGET}" >/dev/null 2>&1; then
  echo "test-install-claude-fixtures: owned-file edit was overwritten" >&2
  exit 1
fi
grep -q 'local edit' "${TARGET}/CLAUDE.md"

# A pre-existing same-name skill is a collision and remains untouched.
COLLISION="${WORK}/collision"
mkdir -p "${COLLISION}/.claude/skills/backend-java-feature"
printf '%s\n' 'do not overwrite' \
  > "${COLLISION}/.claude/skills/backend-java-feature/SKILL.md"
if bash "${ROOT}/scripts/install-claude-fixtures.sh" "${COLLISION}" >/dev/null 2>&1; then
  echo "test-install-claude-fixtures: same-name skill collision was accepted" >&2
  exit 1
fi
grep -qx 'do not overwrite' \
  "${COLLISION}/.claude/skills/backend-java-feature/SKILL.md"

echo "test-install-claude-fixtures: passed"
