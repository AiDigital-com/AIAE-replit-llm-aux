#!/usr/bin/env bash
#
# install-claude-fixtures.sh — install the shared engineering surface into a project.
#
# Copies CLAUDE.md, .claude/rules, .claude/agent_docs, .claude/tasks/README.md and
# the *payload* subset of .claude/skills into a target repository.
#
# Skills are filtered through agent-payload.skills rather than copied wholesale.
# Project-owned payload skills cite canonical `templates/generated-project/**`
# documents in the template state. This installer copies those documents into
# `.claude/agent_docs/**` and rewrites the installed skill citations.
#
# Usage:
#   bash scripts/install-claude-fixtures.sh <target-project-root>

set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_INPUT="${1:?Usage: bash scripts/install-claude-fixtures.sh <target-project-root>}"

if [ ! -d "${TARGET_INPUT}" ]; then
  echo "install-claude-fixtures: target directory does not exist: ${TARGET_INPUT}" >&2
  exit 1
fi

TARGET_ROOT="$(cd "${TARGET_INPUT}" && pwd)"
SOURCE_CLAUDE="${SOURCE_ROOT}/.claude"
TARGET_CLAUDE="${TARGET_ROOT}/.claude"
PAYLOAD_FILE="${SOURCE_ROOT}/agent-payload.skills"
MANAGED_MANIFEST="${TARGET_CLAUDE}/.aiae-fixtures-manifest"

if [ "${SOURCE_ROOT}" = "${TARGET_ROOT}" ]; then
  echo "install-claude-fixtures: source and target are the same directory" >&2
  exit 1
fi

if [ ! -f "${PAYLOAD_FILE}" ]; then
  echo "install-claude-fixtures: missing ${PAYLOAD_FILE}" >&2
  exit 1
fi

PAYLOAD="$(grep -vE '^[[:space:]]*(#|$)' "${PAYLOAD_FILE}" || true)"
if [ -z "${PAYLOAD}" ]; then
  echo "install-claude-fixtures: no skills listed in agent-payload.skills" >&2
  exit 1
fi

# Documentation and rules are installed in full; only skills are filtered.
SHARED_DIRS=(
  agent_docs
  rules
)
CANONICAL_AGENT_DOC_DIRS=(
  auth
  caching
  errors
  frontend
  generation
  integrations
  observability
  openapi
  performance
  structure
  testing
)
REWRITE_PATHS="${SOURCE_ROOT}/templates/generated-project/scaffold/scripts/lib/rewrite-installed-documentation-paths.py"
CHECK_LINKS="${SOURCE_ROOT}/templates/generated-project/scaffold/scripts/lib/check-installed-documentation-links.py"
MANAGED_INSTALLER="${SOURCE_ROOT}/scripts/lib/install-managed-claude-fixtures.py"

echo "==> Install Claude fixtures into ${TARGET_ROOT}"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
STAGE="${WORK}/stage"
mkdir -p "${STAGE}/.claude"

for dir in "${SHARED_DIRS[@]}"; do
  if [ -d "${SOURCE_CLAUDE}/${dir}" ]; then
    mkdir -p "${STAGE}/.claude/${dir}"
    rsync -a "${SOURCE_CLAUDE}/${dir}/" "${STAGE}/.claude/${dir}/"
  fi
done

for dir in "${CANONICAL_AGENT_DOC_DIRS[@]}"; do
  source_docs="${SOURCE_ROOT}/templates/generated-project/${dir}"
  if [ -d "${source_docs}" ]; then
    mkdir -p "${STAGE}/.claude/agent_docs/${dir}"
    rsync -a "${source_docs}/" "${STAGE}/.claude/agent_docs/${dir}/"
  fi
done
python3 "${REWRITE_PATHS}" "${STAGE}/.claude/agent_docs"

echo "==> Install payload skills"
mkdir -p "${STAGE}/.claude/skills"
installed=0
while IFS= read -r skill; do
  [ -n "${skill}" ] || continue
  src="${SOURCE_CLAUDE}/skills/${skill}"
  if [ ! -d "${src}" ]; then
    echo "install-claude-fixtures: payload skill '${skill}' not found in .claude/skills" >&2
    exit 1
  fi
  rsync -a "${src}/" "${STAGE}/.claude/skills/${skill}/"
  installed=$((installed + 1))
  echo "    + ${skill}"
done <<< "${PAYLOAD}"
python3 "${REWRITE_PATHS}" "${STAGE}/.claude/skills"

mkdir -p "${STAGE}/.claude/tasks"
cp "${SOURCE_CLAUDE}/tasks/README.md" "${STAGE}/.claude/tasks/README.md"
cp "${SOURCE_ROOT}/CLAUDE.md" "${STAGE}/CLAUDE.md"
cp "${SOURCE_ROOT}/GDS-WORKFLOW-README.md" "${STAGE}/GDS-WORKFLOW-README.md"
cp "${SOURCE_CLAUDE}/agent_docs/skill-selection.md" \
  "${STAGE}/AI-DEVELOPMENT-GUIDE.md"
cp "${PAYLOAD_FILE}" "${STAGE}/agent-payload.skills"

# Preflight and prepare a merge that preserves unrelated project MCP servers.
# A conflicting context7 definition is a collision, not permission to overwrite.
MERGED_MCP="${WORK}/mcp.json"
python3 - "${SOURCE_ROOT}/.mcp.json" "${TARGET_ROOT}/.mcp.json" "${MERGED_MCP}" <<'PY'
import json
import os
import sys
from pathlib import Path

source_path, target_path, output_path = map(Path, sys.argv[1:])
source = json.loads(source_path.read_text(encoding="utf-8"))
target = {}
if target_path.exists():
    target = json.loads(target_path.read_text(encoding="utf-8"))
if not isinstance(target, dict):
    raise SystemExit("install-claude-fixtures: existing .mcp.json must be an object")
servers = target.setdefault("mcpServers", {})
if not isinstance(servers, dict):
    raise SystemExit("install-claude-fixtures: existing mcpServers must be an object")
context7 = source["mcpServers"]["context7"]
if "context7" in servers and servers["context7"] != context7:
    raise SystemExit("install-claude-fixtures: conflicting context7 MCP definition")
servers["context7"] = context7
temporary = output_path.with_name(f".{output_path.name}.tmp-{os.getpid()}")
temporary.write_text(json.dumps(target, indent=2) + "\n", encoding="utf-8")
os.replace(temporary, output_path)
PY

python3 "${MANAGED_INSTALLER}" "${STAGE}" "${TARGET_ROOT}" "${MANAGED_MANIFEST}"
mkdir -p "${TARGET_ROOT}"
mcp_tmp="${TARGET_ROOT}/.mcp.json.aiae-install.$$"
cp "${MERGED_MCP}" "${mcp_tmp}"
mv "${mcp_tmp}" "${TARGET_ROOT}/.mcp.json"

test -f "${TARGET_CLAUDE}/rules/00-backend-hard-rules.md"
test -f "${TARGET_CLAUDE}/skills/verification-gate/SKILL.md"
test -f "${TARGET_CLAUDE}/skills/task-workflow/SKILL.md"
test -f "${TARGET_ROOT}/CLAUDE.md"
test -f "${TARGET_ROOT}/AI-DEVELOPMENT-GUIDE.md"
test -f "${TARGET_ROOT}/agent-payload.skills"
test -f "${TARGET_ROOT}/.mcp.json"
grep -q 'https://mcp.context7.com/mcp/oauth' "${TARGET_ROOT}/.mcp.json"

# No control-plane leakage: installed content must not point at sources that do
# not exist in the target project.
if grep -rqn "templates/generated-project" "${TARGET_CLAUDE}/skills" 2>/dev/null; then
  echo "install-claude-fixtures: FAILED — an installed skill references templates/generated-project" >&2
  grep -rn "templates/generated-project" "${TARGET_CLAUDE}/skills" >&2
  exit 1
fi
python3 "${CHECK_LINKS}" "${TARGET_ROOT}"

echo "==> install-claude-fixtures: passed — ${installed} skill(s) installed"
echo "    GSD remains optional; see GDS-WORKFLOW-README.md"
