#!/usr/bin/env bash
#
# materialize-project.sh — mechanically copy the scaffold into a generated project.
#
# Usage (from generated project root):
#   bash scripts/materialize-project.sh <app-name-package>
#
# Environment:
#   MATERIALIZE_DEST   — target directory (default: parent of scripts/)
#   SCAFFOLD_ROOT      — override scaffold source path
#   TEMPLATE_REPO_ROOT — repo root for .github/workflows/ci.yml + .template-version

set -euo pipefail

APP_NAME="${1:?Usage: materialize-project.sh <app-name-package>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${MATERIALIZE_DEST:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

fail() {
  echo "materialize-project: $*" >&2
  exit 1
}

resolve_scaffold() {
  if [ -n "${SCAFFOLD_ROOT:-}" ]; then
    printf '%s' "${SCAFFOLD_ROOT}"
    return
  fi
  local here="${SCRIPT_DIR}/.."
  if [ -f "${here}/backend/pom.xml" ] && [ -d "${here}/frontend" ]; then
    printf '%s' "${here}"
    return
  fi
  local from_template="${SCRIPT_DIR}/../../templates/generated-project/scaffold"
  if [ -f "${from_template}/backend/pom.xml" ]; then
    printf '%s' "${from_template}"
    return
  fi
  fail "Cannot locate scaffold source — set SCAFFOLD_ROOT"
}

resolve_template_repo() {
  if [ -n "${TEMPLATE_REPO_ROOT:-}" ]; then
    printf '%s' "${TEMPLATE_REPO_ROOT}"
    return
  fi
  local candidate
  candidate="$(cd "${SCRIPT_DIR}/../../../.." 2>/dev/null && pwd || true)"
  if [ -n "${candidate}" ] && [ -f "${candidate}/replit.md" ]; then
    printf '%s' "${candidate}"
    return
  fi
  candidate="$(cd "${SCRIPT_DIR}/../../.." 2>/dev/null && pwd || true)"
  if [ -n "${candidate}" ] && [ -f "${candidate}/templates/generated-project/scaffold/backend/pom.xml" ]; then
    printf '%s' "${candidate}"
    return
  fi
  printf '%s' ""
}

SCAFFOLD="$(resolve_scaffold)"
TEMPLATE_REPO="$(resolve_template_repo)"

# Docs and rules install in full. Skills are filtered through
# agent-payload.skills and copied to both runtime discovery surfaces.
CLAUDE_SHARED_DIRS=(
  agent_docs
  rules
)

# Topic policies are consumed by the portable skills. They must ship with a
# generated project because the template control plane is absent after
# materialization and engineering handoff.
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

RSYNC_EXCLUDES=(
  --exclude node_modules
  --exclude target
  --exclude generated-sources
  --exclude __pycache__
  --exclude '*.pyc'
  --exclude 'backend/application/src/main/resources/static'
  --exclude tsconfig.tsbuildinfo
)

RUNTIME_SCRIPTS=(
  replit-build.sh
  replit-run.sh
  replit-env.sh
  local-verify.sh
  structure-lint.sh
  verify-gates.sh
  apply-package-name.sh
  strip-scaffold-samples.sh
  remove-cache-management.sh
  remove-usage-logging.sh
  materialize-project.sh
  setup-project.sh
  configure-clerk-development.sh
  docker-local-smoke.sh
  docker-context-path-smoke.sh
  prepare-engineering-handoff.sh
)

# Refuse to run twice, before writing anything.
#
# This script is not an upgrade mechanism. Every copy below is an unconditional
# `rsync`/`cp` from the scaffold, so a second run silently overwrites any
# scaffold-owned file the project has since edited — measured on this repository:
# a modified frontend/src/main.tsx, a project-specific .env.example, and an
# appended CLAUDE.md were all lost, while newly added files survived because the
# copies do not use --delete. Losing the edits and keeping the additions is the
# worst shape of that failure: the project still looks intact.
#
# `.template-version` is written at the very end of a successful run, so a run
# that failed halfway leaves it absent and can be retried.
#
# Upgrading an existing project to a newer template needs a managed-file
# manifest and conflict reporting. That is a separate command, deliberately not
# this one.
if [ -f "${DEST}/.template-version" ]; then
  echo "==> materialize-project: already materialized — nothing to do"
  echo "    ${DEST}/.template-version exists (template $(tr -d '\n' < "${DEST}/.template-version"))."
  echo ""
  echo "    This command scaffolds a new project; it is not a template upgrade."
  echo "    Re-running it would overwrite scaffold-owned files this project may"
  echo "    have changed, so it stops here without modifying anything."
  echo ""
  echo "    To scaffold again, use an empty directory."
  echo "    To adopt a newer template, wait for the upgrade command; it will"
  echo "    report conflicts instead of overwriting."
  exit 0
fi

echo "==> Materialize scaffold from ${SCAFFOLD} to ${DEST}"
mkdir -p "${DEST}/scripts"

rsync -a "${RSYNC_EXCLUDES[@]}" "${SCAFFOLD}/backend/" "${DEST}/backend/"
rsync -a "${RSYNC_EXCLUDES[@]}" "${SCAFFOLD}/frontend/" "${DEST}/frontend/"

for file in .env.example .gitignore docker-compose.yml .replit replit.nix .template-phase; do
  if [ -f "${SCAFFOLD}/${file}" ]; then
    cp "${SCAFFOLD}/${file}" "${DEST}/${file}"
  fi
done

# The generated-project entry point intentionally differs from the template
# control-plane AGENTS.md. Keep the variant as a tracked, explicit template;
# never depend on an ignored scaffold/AGENTS.md that disappears in clean clones.
[ -f "${SCAFFOLD}/AGENTS.md.template" ] \
  || fail "Missing generated-project AGENTS.md.template"
cp "${SCAFFOLD}/AGENTS.md.template" "${DEST}/AGENTS.md"

# A usable .env, not just the example. Both entry points reach this script — the
# Replit onBoot path via setup-project.sh and the local path via new-project.sh — so
# creating it here covers both. Never overwrite: after the first run this file holds
# real values, and .gitignore already excludes it while keeping .env.example tracked.
if [ -f "${DEST}/.env.example" ] && [ ! -f "${DEST}/.env" ]; then
  cp "${DEST}/.env.example" "${DEST}/.env"
  echo "==> created .env from .env.example — fill in real values before running"
fi

if [ -d "${SCAFFOLD}/.husky" ]; then
  mkdir -p "${DEST}/.husky"
  rsync -a "${SCAFFOLD}/.husky/" "${DEST}/.husky/"
  chmod +x "${DEST}/.husky/"* 2>/dev/null || true
fi

if [ -f "${SCAFFOLD}/README.md.template" ] && [ ! -f "${DEST}/README.md" ]; then
  # Substitute only what materialization actually knows: the app name. The owner and
  # the example endpoint row stay as placeholders — inventing an owner or an endpoint
  # that does not exist yet would put fiction in the README, which is worse than an
  # obvious blank.
  sed "s/<APP-NAME>/${APP_NAME}/g" "${SCAFFOLD}/README.md.template" > "${DEST}/README.md"
fi

if [ -f "${SCAFFOLD}/docs/architecture-overview.md.template" ] \
    && [ ! -f "${DEST}/docs/architecture-overview.md" ]; then
  mkdir -p "${DEST}/docs"
  sed "s/<APP-NAME>/${APP_NAME}/g" \
    "${SCAFFOLD}/docs/architecture-overview.md.template" \
    > "${DEST}/docs/architecture-overview.md"
fi

for script in "${RUNTIME_SCRIPTS[@]}"; do
  if [ -f "${SCAFFOLD}/scripts/${script}" ]; then
    cp "${SCAFFOLD}/scripts/${script}" "${DEST}/scripts/${script}"
    chmod +x "${DEST}/scripts/${script}"
  fi
done
if [ -d "${SCAFFOLD}/scripts/lib" ]; then
  mkdir -p "${DEST}/scripts/lib"
  while IFS= read -r -d '' lib_file; do
    cp "${lib_file}" "${DEST}/scripts/lib/$(basename "${lib_file}")"
  done < <(find "${SCAFFOLD}/scripts/lib" -maxdepth 1 -type f ! -name '*.pyc' -print0)
  chmod +x "${DEST}/scripts/lib/"*.sh 2>/dev/null || true
fi

GENERATED_CI="${SCAFFOLD}/../.github/workflows/ci.yml"
if [ -f "${GENERATED_CI}" ]; then
  mkdir -p "${DEST}/.github/workflows"
  cp "${GENERATED_CI}" "${DEST}/.github/workflows/ci.yml"
elif [ -n "${TEMPLATE_REPO}" ] && [ -f "${TEMPLATE_REPO}/templates/generated-project/.github/workflows/ci.yml" ]; then
  mkdir -p "${DEST}/.github/workflows"
  cp "${TEMPLATE_REPO}/templates/generated-project/.github/workflows/ci.yml" "${DEST}/.github/workflows/ci.yml"
fi

if [ -n "${TEMPLATE_REPO}" ] && [ -f "${TEMPLATE_REPO}/CLAUDE.md" ]; then
  cp "${TEMPLATE_REPO}/CLAUDE.md" "${DEST}/CLAUDE.md"
  if [ -f "${TEMPLATE_REPO}/.mcp.json" ]; then
    cp "${TEMPLATE_REPO}/.mcp.json" "${DEST}/.mcp.json"
  fi
  mkdir -p "${DEST}/.claude"
  for claude_dir in "${CLAUDE_SHARED_DIRS[@]}"; do
    if [ -d "${TEMPLATE_REPO}/.claude/${claude_dir}" ]; then
      mkdir -p "${DEST}/.claude/${claude_dir}"
      rsync -a "${TEMPLATE_REPO}/.claude/${claude_dir}/" "${DEST}/.claude/${claude_dir}/"
    fi
  done
  for doc_dir in "${CANONICAL_AGENT_DOC_DIRS[@]}"; do
    if [ -d "${TEMPLATE_REPO}/templates/generated-project/${doc_dir}" ]; then
      mkdir -p "${DEST}/.claude/agent_docs/${doc_dir}"
      rsync -a "${TEMPLATE_REPO}/templates/generated-project/${doc_dir}/" \
        "${DEST}/.claude/agent_docs/${doc_dir}/"
    fi
  done
  python3 "${DEST}/scripts/lib/rewrite-installed-documentation-paths.py" \
    "${DEST}/.claude/agent_docs"
  if [ -f "${TEMPLATE_REPO}/.claude/tasks/README.md" ]; then
    mkdir -p "${DEST}/.claude/tasks"
    cp "${TEMPLATE_REPO}/.claude/tasks/README.md" "${DEST}/.claude/tasks/README.md"
  fi
  if [ -f "${TEMPLATE_REPO}/.claude/agent_docs/skill-selection.md" ]; then
    cp "${TEMPLATE_REPO}/.claude/agent_docs/skill-selection.md" \
      "${DEST}/AI-DEVELOPMENT-GUIDE.md"
  fi

  # Skills: install the portable payload subset into both runtime registries.
  # The template-only `project-init` skill stays at the control plane.
  payload_file="${TEMPLATE_REPO}/agent-payload.skills"
  if [ ! -f "${payload_file}" ]; then
    fail "missing ${payload_file} — cannot determine which skills to install"
  fi
  cp "${payload_file}" "${DEST}/agent-payload.skills"
  mkdir -p "${DEST}/.claude/skills" "${DEST}/.agents/skills"
  while IFS= read -r skill; do
    case "${skill}" in ''|\#*) continue ;; esac
    claude_src="${TEMPLATE_REPO}/.claude/skills/${skill}"
    agents_src="${TEMPLATE_REPO}/.agents/skills/${skill}"
    [ -d "${claude_src}" ] || fail "payload skill '${skill}' not found in .claude/skills"
    [ -d "${agents_src}" ] || fail "payload skill '${skill}' not found in .agents/skills"
    rsync -a --delete "${claude_src}/" "${DEST}/.claude/skills/${skill}/"
    rsync -a --delete "${agents_src}/" "${DEST}/.agents/skills/${skill}/"
  done < <(grep -vE '^[[:space:]]*(#|$)' "${payload_file}")

  # Project-owned skills are active in two lifecycle states. In the template
  # control plane they cite canonical `templates/generated-project/**` sources;
  # in a materialized project those same documents live under
  # `.claude/agent_docs/**`. Compile the copied registries after installation so
  # every citation resolves in the environment where the skill runs.
  python3 "${DEST}/scripts/lib/rewrite-installed-documentation-paths.py" \
    "${DEST}/.claude/skills"
  python3 "${DEST}/scripts/lib/rewrite-installed-documentation-paths.py" \
    "${DEST}/.agents/skills"

  if grep -rqn "templates/generated-project" \
      "${DEST}/.claude/agent_docs" \
      "${DEST}/.claude/skills" \
      "${DEST}/.agents/skills" 2>/dev/null; then
    echo "materialize-project: an installed portable file references a removed template path" >&2
    grep -rn "templates/generated-project" \
      "${DEST}/.claude/agent_docs" \
      "${DEST}/.claude/skills" \
      "${DEST}/.agents/skills" >&2
    fail "control-plane leakage into the generated project"
  fi
fi

# Replit Agent surface. The template repository and an active generated project
# have different responsibilities, so both entry points use explicit scaffold
# templates rather than copying the control-plane prose.
[ -f "${SCAFFOLD}/replit.md.template" ] \
  || fail "Missing generated-project replit.md.template"
cp "${SCAFFOLD}/replit.md.template" "${DEST}/replit.md"

version_file="${DEST}/.template-version"
if [ -n "${TEMPLATE_REPO}" ] && [ -d "${TEMPLATE_REPO}/.git" ]; then
  git -C "${TEMPLATE_REPO}" rev-parse HEAD > "${version_file}" 2>/dev/null \
    || date -u +"%Y-%m-%dT%H:%M:%SZ" > "${version_file}"
else
  date -u +"%Y-%m-%dT%H:%M:%SZ" > "${version_file}"
fi

cd "${DEST}"

echo "==> Apply package name ${APP_NAME}"
bash scripts/apply-package-name.sh "${APP_NAME}"

# Reaching here means this was a first materialization: the guard above returns
# early otherwise. So the gates always run, and there is no longer a path that
# scaffolds a project without verifying it.
echo "==> structure-lint + verify-gates"
STRUCTURE_LINT_ALLOW_SAMPLE=1 bash scripts/structure-lint.sh
bash scripts/verify-gates.sh

echo "==> materialize-project: passed"
