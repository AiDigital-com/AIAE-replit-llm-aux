#!/usr/bin/env bash
#
# test-materialize-project.sh — contract tests for materialize-project.sh.
# Run from anywhere; creates and cleans up a temporary directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCAFFOLD="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE_ROOT="$(cd "${SCAFFOLD}/../../.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

assert_file()   { [ -f "$1" ]  && pass "$1 present"  || fail "$1 should exist"; }
assert_absent() { [ ! -e "$1" ] && pass "$1 absent"  || fail "$1 should be absent"; }
assert_contains() { grep -Fq -- "$2" "$1" && pass "$1 contains '$2'" || fail "$1 should contain '$2'"; }
assert_not_contains() { grep -Fq -- "$2" "$1" && fail "$1 should NOT contain '$2'" || pass "$1 does not contain '$2'"; }

run_materialize() {
  local dest="$1"; shift
  SCAFFOLD_ROOT="${SCAFFOLD}" \
    MATERIALIZE_DEST="${dest}" \
    TEMPLATE_REPO_ROOT="${TEMPLATE_ROOT}" \
    bash "${SCRIPT_DIR}/materialize-project.sh" "$@" 2>&1 >/dev/null
}

mktemp_dir() { mktemp -d; }

if command -v shasum >/dev/null 2>&1; then SHA_CMD=(shasum -a 256)
else SHA_CMD=(sha256sum)
fi

# ─── Test 0: active template-control-plane references resolve ─────────────────
echo "==> Test 0: template-state skill references resolve"
assert_contains \
  "${TEMPLATE_ROOT}/.agents/skills/backend-java-feature/SKILL.md" \
  "templates/generated-project/openapi/canonical-openapi-rules.md"
assert_file \
  "${TEMPLATE_ROOT}/templates/generated-project/openapi/canonical-openapi-rules.md"
assert_contains \
  "${TEMPLATE_ROOT}/.claude/skills/frontend-react-feature/SKILL.md" \
  "templates/generated-project/frontend/canonical-react-frontend-rules.md"
assert_file \
  "${TEMPLATE_ROOT}/templates/generated-project/frontend/canonical-react-frontend-rules.md"

# ─── Test 1: complete generated root surface ──────────────────────────────────
echo "==> Test 1: materialized root contains required files"
T1="$(mktemp_dir)"
trap 'rm -rf "${T1}"' EXIT

run_materialize "${T1}" replitmvp
assert_file "${T1}/backend/pom.xml"
assert_file "${T1}/backend/DEPENDENCY-ANALYSIS.md"
assert_not_contains "${T1}/backend/pom.xml" "-javaagent:\${settings.localRepository}/org/mockito"
assert_file "${T1}/frontend/package.json"
assert_file "${T1}/.env.example"
assert_file "${T1}/.gitignore"
assert_file "${T1}/docker-compose.yml"
assert_file "${T1}/.replit"
assert_file "${T1}/replit.nix"
assert_file "${T1}/.template-version"
assert_file "${T1}/.github/workflows/ci.yml"
assert_file "${T1}/scripts/materialize-project.sh"
assert_file "${T1}/scripts/setup-project.sh"
assert_file "${T1}/scripts/local-verify.sh"
assert_file "${T1}/scripts/docker-local-smoke.sh"
assert_file "${T1}/scripts/docker-context-path-smoke.sh"
assert_file "${T1}/scripts/lib/scan-production-java.py"
assert_file "${T1}/scripts/lib/liquibase_dependency_guard.py"
assert_file "${T1}/CLAUDE.md"
assert_file "${T1}/.mcp.json"
assert_contains "${T1}/.mcp.json" "https://mcp.context7.com/mcp/oauth"
assert_not_contains "${T1}/.mcp.json" "CONTEXT7_API_KEY"
assert_file "${T1}/AI-DEVELOPMENT-GUIDE.md"
assert_file "${T1}/.claude/agent_docs/index.md"
assert_file "${T1}/.claude/rules/00-backend-hard-rules.md"
assert_file "${T1}/.claude/rules/40-frontend-rules.md"
assert_file "${T1}/.claude/skills/task-workflow/SKILL.md"
assert_file "${T1}/.claude/skills/verification-gate/SKILL.md"
assert_file "${T1}/.claude/agent_docs/skill-selection.md"
assert_file "${T1}/.claude/agent_docs/openapi/canonical-openapi-rules.md"
assert_file "${T1}/.claude/agent_docs/testing/testing-policy.md"
assert_file "${T1}/.claude/agent_docs/structure/near-production-project-structure.md"
assert_file "${T1}/.claude/agent_docs/auth/google-sso-clerk-blueprint.md"
assert_file "${T1}/.claude/agent_docs/performance/performance-engineering-rules.md"
assert_file "${T1}/.claude/tasks/README.md"

trap - EXIT
rm -rf "${T1}"

# ─── Test 2: dual discovery surfaces and portable payload ────────────────────
echo "==> Test 2: dual discovery surfaces and portable payload"
T2="$(mktemp_dir)"
trap 'rm -rf "${T2}"' EXIT

run_materialize "${T2}" replitmvp
# Both agent entry points present.
assert_file "${T2}/AGENTS.md"
assert_file "${T2}/replit.md"
assert_contains "${T2}/replit.md" "This is an active dual-agent development project"
assert_not_contains "${T2}/replit.md" "templates/generated-project"
assert_not_contains "${T2}/replit.md" "custom_instruction/"
assert_file "${T2}/CLAUDE.md"
assert_file "${T2}/.mcp.json"
assert_file "${T2}/AI-DEVELOPMENT-GUIDE.md"
assert_file "${T2}/agent-payload.skills"
# Both registries are discovered by their respective runtimes; task state is
# shared under .claude/tasks.
assert_file "${T2}/.agents/skills/verification-gate/SKILL.md"
assert_file "${T2}/.agents/skills/verification-gate/agents/openai.yaml"
assert_file "${T2}/.agents/skills/task-workflow/SKILL.md"
assert_file "${T2}/.claude/agent_docs/rule-loading-conventions.md"
assert_file "${T2}/.claude/agent_docs/distributed_cache.md"
assert_file "${T2}/.claude/agent_docs/context7.md"
assert_file "${T2}/.claude/skills/verification-gate/SKILL.md"
assert_file "${T2}/.claude/skills/verification-gate/agents/openai.yaml"
assert_file "${T2}/.claude/skills/task-workflow/SKILL.md"
assert_file "${T2}/.claude/skills/production-code-review/SKILL.md"
assert_file "${T2}/.claude/skills/fullstack-performance-audit/SKILL.md"
assert_absent "${T2}/.claude/skills/rule-compliance-audit"
# Project-owned payload skills ship too.
assert_file "${T2}/.claude/skills/backend-rule-review/SKILL.md"
assert_file "${T2}/.claude/skills/frontend-style-review/SKILL.md"
assert_file "${T2}/.claude/skills/aiae-rule-compliance-audit/SKILL.md"
assert_contains \
  "${T2}/.claude/skills/aiae-rule-compliance-audit/SKILL.md" \
  "RULE_DISTRIBUTION_PROBLEM"
assert_contains \
  "${T2}/.agents/skills/aiae-rule-compliance-audit/SKILL.md" \
  '2. `AGENTS.md` when the active Replit surface is present;'
assert_file "${T2}/.claude/skills/ui-designer/SKILL.md"
# finalize-coverage runs inside the project, so it ships; project-init does not.
assert_file "${T2}/.claude/skills/finalize-coverage/SKILL.md"
assert_absent "${T2}/.claude/skills/project-init"
# Coverage phase starts relaxed, and the integrity machinery travels with it.
assert_file "${T2}/.template-phase"
assert_contains "${T2}/.template-phase" "mvp"
assert_file "${T2}/scripts/lib/coverage-phase.sh"
assert_file "${T2}/scripts/lib/check-coverage-integrity.sh"
assert_file "${T2}/scripts/lib/check-thin-controllers.py"
assert_file "${T2}/scripts/lib/check-openapi-input-constraints.py"
assert_file "${T2}/scripts/lib/check-api-validation-tests.py"
assert_file "${T2}/scripts/lib/check-installed-documentation-links.py"
assert_file "${T2}/scripts/lib/check-maven-dependency-analysis.py"
assert_file "${T2}/scripts/lib/rewrite-installed-documentation-paths.py"
# Portable Replit workflows ship in both registries. project-init is template-only.
for runtime_skill in backend-java-feature frontend-react-feature openapi-contract-first mvp-safety-review engineering-handoff finalize-coverage; do
  assert_file "${T2}/.claude/skills/${runtime_skill}/SKILL.md"
  assert_file "${T2}/.agents/skills/${runtime_skill}/SKILL.md"
done
assert_absent "${T2}/.claude/skills/project-init"
assert_absent "${T2}/.agents/skills/project-init"
assert_contains \
  "${T2}/.agents/skills/backend-java-feature/SKILL.md" \
  ".claude/agent_docs/openapi/canonical-openapi-rules.md"
assert_not_contains \
  "${T2}/.agents/skills/backend-java-feature/SKILL.md" \
  "templates/generated-project"
if python3 "${T2}/scripts/lib/check-installed-documentation-links.py" "${T2}" >/dev/null; then
  pass "installed skill and documentation references resolve"
else
  fail "installed skill and documentation references should resolve"
fi
expected_payload="$(grep -vE '^[[:space:]]*(#|$)' "${T2}/agent-payload.skills" | LC_ALL=C sort)"
for registry in .claude/skills .agents/skills; do
  actual_payload="$(
    find "${T2}/${registry}" -mindepth 2 -maxdepth 2 -name SKILL.md -print \
      | sed "s#^${T2}/${registry}/##; s#/SKILL.md\$##" \
      | LC_ALL=C sort
  )"
  [ "$actual_payload" = "$expected_payload" ] \
    || fail "${registry} must exactly match agent-payload.skills"
done
# Generated provenance on common skills.
assert_contains "${T2}/.claude/skills/verification-gate/SKILL.md" "Generated file. Do not edit directly."
# No unresolved placeholders in generated skills.
assert_not_contains "${T2}/.claude/skills/task-workflow/SKILL.md" "{{TASK_STATE_DIR}}"
# One shared task-state directory, so both agents read each other's artifacts.
assert_contains "${T2}/.claude/skills/task-workflow/SKILL.md" ".claude/tasks"
assert_not_contains "${T2}/.claude/skills/task-workflow/SKILL.md" ".agents/tasks"
# No shipped skill points at the control-plane tree.
if grep -rqn "templates/generated-project" "${T2}/.claude/skills" 2>/dev/null; then
  echo "FAIL: a shipped skill references templates/generated-project"
  grep -rn "templates/generated-project" "${T2}/.claude/skills"
  exit 1
fi
if grep -rqn "templates/generated-project" "${T2}/.agents/skills" 2>/dev/null; then
  echo "FAIL: a Replit skill references templates/generated-project"
  grep -rn "templates/generated-project" "${T2}/.agents/skills"
  exit 1
fi
# Template control-plane still excluded.
assert_absent "${T2}/custom_instruction"
assert_absent "${T2}/templates"
assert_absent "${T2}/scripts/ci-verify-scaffold.sh"
# Handoff script available.
assert_file "${T2}/scripts/prepare-engineering-handoff.sh"
assert_file "${T2}/scripts/remove-cache-management.sh"
assert_file "${T2}/scripts/remove-usage-logging.sh"
assert_file "${T2}/scripts/lib/remove-cache-management.py"
assert_file "${T2}/scripts/lib/remove-usage-logging.py"
assert_file "${T2}/backend/migrations/src/main/resources/db/changelog/changes/0003-cache-invalidation.xml"
assert_file "${T2}/backend/service/src/main/java/com/aidigital/replitmvp/service/cache/JpaCacheInvalidationEventService.java"
assert_contains "${T2}/backend/service/pom.xml" "<artifactId>cache-management</artifactId>"
assert_contains "${T2}/backend/application/src/main/java/com/aidigital/replitmvp/Application.java" "@EnableScheduling"
assert_not_contains "${T2}/.claude/agent_docs/openapi/canonical-openapi-rules.md" "templates/generated-project"
assert_contains "${T2}/.claude/agent_docs/openapi/canonical-openapi-rules.md" "backend/pom.xml"

trap - EXIT
rm -rf "${T2}"

# ─── Test 3: package name replaced ────────────────────────────────────────────
echo "==> Test 3: PACKAGE_REPLACE_ME replaced after materialization"
T3="$(mktemp_dir)"
trap 'rm -rf "${T3}"' EXIT

run_materialize "${T3}" replitmvp
remaining="$(find "${T3}/backend" -path '*/src/*' -name '*.java' -print0 2>/dev/null \
  | xargs -0 grep -l 'PACKAGE_REPLACE_ME' 2>/dev/null | wc -l | tr -d ' ')" || remaining=0
[ "${remaining}" -eq 0 ] \
  && pass "no PACKAGE_REPLACE_ME in backend/src" \
  || fail "${remaining} files still contain PACKAGE_REPLACE_ME"

trap - EXIT
rm -rf "${T3}"

# ─── Test 4: a second run is a no-op, not an upgrade ──────────────────────────
# Every copy in materialize-project.sh is an unconditional rsync/cp, so before
# the guard a second run overwrote edited scaffold-owned files while keeping newly
# added ones. Measured losses: frontend/src/main.tsx, .env.example, CLAUDE.md.
# Asserting a whole-tree digest rather than a file list is deliberate — a list
# only covers the losses someone already thought of.
echo "==> Test 4: second materialization modifies nothing at all"
T4="$(mktemp_dir)"
trap 'rm -rf "${T4}"' EXIT

run_materialize "${T4}" replitmvp

# Edit files the scaffold owns, and add one it does not.
printf '\n// project-specific change\n' >> "${T4}/frontend/src/main.tsx"
echo "CUSTOMER_PLACEHOLDER=replace-me" > "${T4}/.env.example"
printf '\n<!-- project-specific agent context -->\n' >> "${T4}/CLAUDE.md"
echo "MY REAL APP README" > "${T4}/README.md"
echo "export const feature = true;" > "${T4}/frontend/src/user-feature.ts"

tree_digest() {
  ( cd "$1" && find . -type f \
      -not -path './node_modules/*' -not -path '*/node_modules/*' \
      -not -path '*/target/*' -not -path './.git/*' -print0 \
    | LC_ALL=C sort -z | xargs -0 "${SHA_CMD[@]}" 2>/dev/null | "${SHA_CMD[@]}" )
}

DIGEST_BEFORE="$(tree_digest "${T4}")"

# Assert the guard by its own message as well as by the digest. Without this, a
# removed guard surfaces as an unrelated verify-gates complaint about whichever
# file the test happened to edit, which sends the reader to the wrong place.
SECOND_RUN_OUTPUT="$(
  SCAFFOLD_ROOT="${SCAFFOLD}" MATERIALIZE_DEST="${T4}" TEMPLATE_REPO_ROOT="${TEMPLATE_ROOT}" \
    bash "${SCRIPT_DIR}/materialize-project.sh" replitmvp 2>&1 || true
)"
DIGEST_AFTER="$(tree_digest "${T4}")"

printf '%s' "${SECOND_RUN_OUTPUT}" | grep -Fq "already materialized" \
  && pass "second run refused with the already-materialized guard" \
  || fail "second run did not report the already-materialized guard"

[ "${DIGEST_BEFORE}" = "${DIGEST_AFTER}" ] \
  && pass "second run left the tree byte-identical" \
  || fail "second run modified the project tree"

assert_contains "${T4}/frontend/src/main.tsx" "project-specific change"
assert_contains "${T4}/.env.example" "CUSTOMER_PLACEHOLDER"
assert_contains "${T4}/CLAUDE.md" "project-specific agent context"
assert_contains "${T4}/README.md" "MY REAL APP README"
assert_file "${T4}/frontend/src/user-feature.ts"

trap - EXIT
rm -rf "${T4}"

# ─── Test 5: a half-finished materialization can still be retried ─────────────
# The guard keys on .template-version, written only at the end of a successful
# run. Without this case, tightening the guard to something written earlier would
# leave a failed run permanently unrepeatable.
echo "==> Test 5: absent .template-version allows materialization to proceed"
T5="$(mktemp_dir)"
trap 'rm -rf "${T5}"' EXIT

run_materialize "${T5}" replitmvp
rm -f "${T5}/.template-version"
rm -f "${T5}/docker-compose.yml"
run_materialize "${T5}" replitmvp
assert_file "${T5}/docker-compose.yml"
assert_file "${T5}/.template-version"

trap - EXIT
rm -rf "${T5}"

# ─── Test 6: .replit and replit.nix present ───────────────────────────────────
echo "==> Test 6: .replit and replit.nix materialized"
T6="$(mktemp_dir)"
trap 'rm -rf "${T6}"' EXIT

run_materialize "${T6}" replitmvp
assert_file "${T6}/.replit"
assert_file "${T6}/replit.nix"
assert_contains "${T6}/.replit" "onBoot"

trap - EXIT
rm -rf "${T6}"

# ─── Test 7: engineering handoff removes Replit surface ──────────────────────
echo "==> Test 7: prepare-engineering-handoff removes control plane, preserves Claude"
T7="$(mktemp_dir)"
trap 'rm -rf "${T7}"' EXIT

run_materialize "${T7}" replitmvp
# Before handoff: both entry points and the shared registry are present.
assert_file "${T7}/AGENTS.md"
assert_file "${T7}/replit.md"
assert_file "${T7}/CLAUDE.md"
assert_file "${T7}/.mcp.json"
assert_file "${T7}/.claude/skills/verification-gate/SKILL.md"

# A materialized project starts in the relaxed MVP coverage phase.
assert_file "${T7}/.template-phase"
assert_contains "${T7}/.template-phase" "mvp"

# Removing the foundational usage_events migration must fail closed when a
# later active changelog still depends on that table.
USAGE_INCLUDE_ALL_DIR="${T7}/backend/migrations/src/main/resources/db/changelog/extra/release-1"
USAGE_DEPENDENT_CHANGELOG="${USAGE_INCLUDE_ALL_DIR}/0004-usage-events-report.xml"
mkdir -p "${USAGE_INCLUDE_ALL_DIR}"
cat > "${USAGE_DEPENDENT_CHANGELOG}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog xmlns="http://www.liquibase.org/xml/ns/dbchangelog">
  <changeSet id="0004-usage-events-report" author="test">
    <preConditions onFail="HALT">
      <tableExists tableName="usage_events"/>
    </preConditions>
    <addColumn tableName="usage_events">
      <column name="report_bucket" type="TEXT"/>
    </addColumn>
  </changeSet>
</databaseChangeLog>
EOF
python3 - "${T7}/backend/migrations/src/main/resources/db/changelog/db.changelog-master.xml" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
marker = "    <!-- Add new changelogs above this line in numerically increasing order. -->"
path.write_text(
    text.replace(
        marker,
        '    <includeAll path="db/changelog/extra"/>\n'
        + marker,
    ),
    encoding="utf-8",
)
PY
if usage_guard_output="$(bash "${T7}/scripts/remove-usage-logging.sh" 2>&1)"; then
  fail "usage removal should reject a downstream usage_events migration"
elif grep -Fq "0004-usage-events-report.xml" <<< "${usage_guard_output}"; then
  pass "usage removal identifies the downstream migration"
else
  fail "usage removal rejected without downstream file evidence"
fi
rm -f "${USAGE_DEPENDENT_CHANGELOG}"
rmdir "${USAGE_INCLUDE_ALL_DIR}" "${USAGE_INCLUDE_ALL_DIR%/release-1}"
python3 - "${T7}/backend/migrations/src/main/resources/db/changelog/db.changelog-master.xml" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(
    text.replace(
        '    <includeAll path="db/changelog/extra"/>\n',
        "",
    ),
    encoding="utf-8",
)
PY

# The active dual-agent runtime must survive a normal git add/commit/clone.
git -C "${T7}" init -q
git -C "${T7}" config user.email "template-test@aidigital.test"
git -C "${T7}" config user.name "Template Test"
git -C "${T7}" add -A
for tracked in AGENTS.md replit.md .agents/skills/verification-gate/SKILL.md \
               CLAUDE.md .claude/skills/verification-gate/SKILL.md; do
  git -C "${T7}" ls-files --error-unmatch "${tracked}" >/dev/null 2>&1 \
    || { echo "FAIL: active runtime file was not staged: ${tracked}"; exit 1; }
done
git -C "${T7}" commit -qm "materialized active project"
T7_CLONE="$(mktemp_dir)"
git clone -q "${T7}" "${T7_CLONE}"
assert_file "${T7_CLONE}/AGENTS.md"
assert_file "${T7_CLONE}/replit.md"
assert_file "${T7_CLONE}/.agents/skills/verification-gate/SKILL.md"
rm -rf "${T7_CLONE}"

# Coverage finalization is the required last step, and handoff is what it gates.
# While the phase is mvp, handoff must refuse.
if bash "${T7}/scripts/prepare-engineering-handoff.sh" --target "${T7}" --apply >/dev/null 2>&1; then
  echo "FAIL: handoff proceeded while coverage phase was still 'mvp'"
  exit 1
fi
assert_file "${T7}/AGENTS.md"
echo "  PASS: handoff blocked while coverage phase is 'mvp'"

# Finalize coverage (the phase flip is what finalize-coverage ends with).
echo engineering > "${T7}/.template-phase"
git -C "${T7}" add .template-phase
git -C "${T7}" commit -qm "finalize coverage phase"

# A real project replaces the copyable feature template before handoff. Keep a
# minimal product entry point so this focused lifecycle fixture proves the
# handoff removes the now-unreferenced directory without guessing at routes.
cat > "${T7}/frontend/src/App.tsx" <<'EOF'
export default function App() {
  return <main>Product application</main>;
}
EOF
git -C "${T7}" add frontend/src/App.tsx
git -C "${T7}" commit -qm "replace scaffold frontend feature"

# The real post-removal structure gate must accept an engineering project
# without copyable teaching source. Keep the full local-verify probe below
# focused on fail-closed command invocation, but exercise the formerly masked
# structure-lint path here.
mv \
  "${T7}/frontend/src/features/_template" \
  "${T7}/frontend/src/features/.handoff-template-backup"
STRUCTURE_LINT_ALLOW_SAMPLE=1 STRUCTURE_LINT_ROOT="${T7}" \
  bash "${T7}/scripts/structure-lint.sh" >/dev/null
mv \
  "${T7}/frontend/src/features/.handoff-template-backup" \
  "${T7}/frontend/src/features/_template"
pass "engineering structure-lint accepts the post-handoff frontend tree"

# Handoff is opt-in: a bare run is a dry run and must change nothing.
bash "${T7}/scripts/prepare-engineering-handoff.sh" --target "${T7}" >/dev/null 2>&1
assert_file "${T7}/AGENTS.md"
assert_file "${T7}/replit.md"

# Replace the expensive verification command in this focused lifecycle fixture
# with a committed probe. Production code invokes this fixed path directly; the
# full implementation is exercised separately by ci-verify-scaffold.sh.
cat > "${T7}/scripts/local-verify.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'invoked\n' > "${HANDOFF_TEST_MARKER:?}"
exit "${HANDOFF_TEST_VERIFY_EXIT:-0}"
EOF
chmod +x "${T7}/scripts/local-verify.sh"
git -C "${T7}" add scripts/local-verify.sh
git -C "${T7}" commit -qm "install focused verification probe"

# A caller-written receipt is not authorization. A failing fresh verification
# must block handoff and preserve the active Replit surface.
cat > "${T7}/.claude/tasks/engineering-verification.receipt" <<EOF
phase=engineering
git_head=$(git -C "${T7}" rev-parse HEAD)
verified_at_epoch=$(date +%s)
verification_command=bash scripts/local-verify.sh
EOF
HANDOFF_MARKER="${T7}-handoff-verification-invoked"
if HANDOFF_TEST_MARKER="${HANDOFF_MARKER}" HANDOFF_TEST_VERIFY_EXIT=23 \
    bash "${T7}/scripts/prepare-engineering-handoff.sh" --target "${T7}" --apply >/dev/null 2>&1; then
  echo "FAIL: handoff ignored a failing fresh local verification"
  exit 1
fi
assert_file "${T7}/AGENTS.md"
assert_file "${HANDOFF_MARKER}"

# The failed verification happens after the reversible telemetry-removal diff
# was produced. Preserve that reviewed transformation as the clean checkpoint
# required by the next handoff attempt.
git -C "${T7}" add -A
git -C "${T7}" commit -qm "remove MVP usage logging"

# Now apply with a successful command and verify the post-handoff gates remain
# valid in Claude-only lifecycle mode.
HANDOFF_TEST_MARKER="${HANDOFF_MARKER}" \
  bash "${T7}/scripts/prepare-engineering-handoff.sh" --target "${T7}" --apply >/dev/null 2>&1
# After handoff: Replit control plane removed.
assert_absent "${T7}/AGENTS.md"
assert_absent "${T7}/replit.md"
assert_absent "${T7}/.agents"
assert_absent "${T7}/custom_instruction"
assert_absent "${T7}/templates"
# After handoff: the Claude surface is preserved and self-contained.
assert_file "${T7}/CLAUDE.md"
assert_file "${T7}/.mcp.json"
assert_file "${T7}/.claude/skills/verification-gate/SKILL.md"
assert_file "${T7}/.claude/skills/task-workflow/SKILL.md"
assert_file "${T7}/.claude/rules/00-backend-hard-rules.md"
assert_absent "${T7}/backend/event-logging-to-db-feature"
assert_absent "${T7}/backend/migrations/src/main/resources/db/changelog/changes/0001-usage-events.xml"
assert_not_contains "${T7}/backend/pom.xml" "event-logging-to-db-feature"
assert_not_contains "${T7}/backend/service/pom.xml" "event-logging-to-db-feature"
assert_absent "${T7}/frontend/src/features/_template"
assert_absent "${T7}/frontend/src/features/_templates"
assert_contains "${T7}/scripts/lib/check-agent-surfaces.sh" "handoff"
VERIFY_ROOT="${T7}" bash "${T7}/scripts/verify-gates.sh" >/dev/null
# Nothing surviving references the tree that was just deleted.
python3 "${T7}/scripts/lib/check-installed-documentation-links.py" "${T7}" >/dev/null

trap - EXIT
rm -rf "${T7}"
rm -f "${HANDOFF_MARKER}"

# ─── Test 8: no-cache projects remove the whole stack atomically ─────────────
echo "==> Test 8: remove-cache-management produces a coherent no-cache project"
T8="$(mktemp_dir)"
trap 'rm -rf "${T8}"' EXIT

run_materialize "${T8}" replitmvp
bash "${T8}/scripts/remove-cache-management.sh" >/dev/null
assert_file "${T8}/backend/cache-management/pom.xml"

# A direct API usage must block removal before its javax.cache dependency is
# deleted, even when it uses none of the scaffold annotations.
DIRECT_CACHE_USAGE="${T8}/backend/application/src/main/java/com/aidigital/replitmvp/DirectCacheUsage.java"
cat > "${DIRECT_CACHE_USAGE}" <<'EOF'
package com.aidigital.replitmvp;

import javax.cache.CacheManager;

final class DirectCacheUsage {
    private CacheManager cacheManager;
}
EOF
if cache_api_guard_output="$(bash "${T8}/scripts/remove-cache-management.sh" 2>&1)"; then
  fail "cache removal should reject direct javax.cache API usage"
elif grep -Fq "DirectCacheUsage.java" <<< "${cache_api_guard_output}"; then
  pass "cache removal identifies direct cache API usage"
else
  fail "cache removal rejected without direct-usage file evidence"
fi
rm -f "${DIRECT_CACHE_USAGE}"

# Hibernate query caching can be enabled without Spring cache annotations or
# javax.cache types. Its fluent API and hint constants must also block removal.
QUERY_CACHE_USAGE="${T8}/backend/application/src/main/java/com/aidigital/replitmvp/QueryCacheUsage.java"
cat > "${QUERY_CACHE_USAGE}" <<'EOF'
package com.aidigital.replitmvp;

import org.hibernate.jpa.HibernateHints;
import org.hibernate.query.Query;

final class QueryCacheUsage {
    void enable(Query<?> query) {
        query.setHint(HibernateHints.HINT_CACHEABLE, true);
        query.setCacheable(true);
        query.setCacheRegion("product-query");
    }
}
EOF
if query_cache_guard_output="$(bash "${T8}/scripts/remove-cache-management.sh" 2>&1)"; then
  fail "cache removal should reject Hibernate query-cache API usage"
elif grep -Fq "QueryCacheUsage.java" <<< "${query_cache_guard_output}"; then
  pass "cache removal identifies Hibernate query-cache usage"
else
  fail "cache removal rejected without query-cache file evidence"
fi
rm -f "${QUERY_CACHE_USAGE}"

# A later active migration may extend the invalidation table. Removing its
# foundational changelog in that state must fail closed with file evidence.
CACHE_DEPENDENT_CHANGELOG="${T8}/backend/migrations/src/main/resources/db/changelog/changes/0004-cache-consumer.xml"
CACHE_DEPENDENT_SQL="${T8}/backend/migrations/src/main/resources/db/changelog/changes/0004-cache-consumer.sql"
cat > "${CACHE_DEPENDENT_CHANGELOG}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog xmlns="http://www.liquibase.org/xml/ns/dbchangelog">
  <changeSet id="0004-cache-consumer" author="test">
    <preConditions onFail="HALT">
      <tableExists tableName="cache_invalidation_event"/>
    </preConditions>
    <sqlFile path="db/changelog/changes/0004-cache-consumer.sql"/>
  </changeSet>
</databaseChangeLog>
EOF
cat > "${CACHE_DEPENDENT_SQL}" <<'EOF'
ALTER TABLE cache_invalidation_event ADD COLUMN consumer TEXT;
EOF
python3 - "${T8}/backend/migrations/src/main/resources/db/changelog/db.changelog-master.xml" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
marker = "    <!-- Add new changelogs above this line in numerically increasing order. -->"
path.write_text(
    text.replace(
        marker,
        '    <include file="db/changelog/changes/0004-cache-consumer.xml"/>\n'
        + marker,
    ),
    encoding="utf-8",
)
PY
if cache_migration_guard_output="$(bash "${T8}/scripts/remove-cache-management.sh" 2>&1)"; then
  fail "cache removal should reject a downstream invalidation-table migration"
elif grep -Fq "0004-cache-consumer.sql" <<< "${cache_migration_guard_output}"; then
  pass "cache removal identifies referenced downstream SQL"
else
  fail "cache removal rejected without downstream file evidence"
fi
rm -f "${CACHE_DEPENDENT_CHANGELOG}" "${CACHE_DEPENDENT_SQL}"
python3 - "${T8}/backend/migrations/src/main/resources/db/changelog/db.changelog-master.xml" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(
    text.replace(
        '    <include file="db/changelog/changes/0004-cache-consumer.xml"/>\n',
        "",
    ),
    encoding="utf-8",
)
PY

# includeAll loads formatted SQL files directly and recursively. That graph edge
# must be guarded too; it is not equivalent to an inert loose SQL file.
CACHE_INCLUDE_ALL_DIR="${T8}/backend/migrations/src/main/resources/db/changelog/cache-extra"
CACHE_INCLUDE_ALL_SQL="${CACHE_INCLUDE_ALL_DIR}/0005-cache-direct.sql"
mkdir -p "${CACHE_INCLUDE_ALL_DIR}"
cat > "${CACHE_INCLUDE_ALL_SQL}" <<'EOF'
--liquibase formatted sql
--changeset test:0005-cache-direct
--preconditions onFail:HALT
--precondition-sql-check expectedResult:0 SELECT COUNT(*) FROM cache_invalidation_event
SELECT 1;
EOF
python3 - "${T8}/backend/migrations/src/main/resources/db/changelog/db.changelog-master.xml" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
marker = "    <!-- Add new changelogs above this line in numerically increasing order. -->"
path.write_text(
    text.replace(
        marker,
        '    <includeAll path="db/changelog/cache-extra"/>\n' + marker,
    ),
    encoding="utf-8",
)
PY
if cache_include_all_output="$(bash "${T8}/scripts/remove-cache-management.sh" 2>&1)"; then
  fail "cache removal should reject direct SQL loaded by includeAll"
elif grep -Fq "0005-cache-direct.sql" <<< "${cache_include_all_output}"; then
  pass "cache removal identifies direct SQL loaded by includeAll"
else
  fail "cache removal rejected includeAll without SQL file evidence"
fi
rm -f "${CACHE_INCLUDE_ALL_SQL}"
rmdir "${CACHE_INCLUDE_ALL_DIR}"
python3 - "${T8}/backend/migrations/src/main/resources/db/changelog/db.changelog-master.xml" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(
    text.replace(
        '    <includeAll path="db/changelog/cache-extra"/>\n',
        "",
    ),
    encoding="utf-8",
)
PY

python3 - "${T8}/backend/application/src/main/resources/application.yml" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
needle = "  auth:\n"
if text.count(needle) != 1:
    raise SystemExit("expected one app.auth block")
path.write_text(
    text.replace(
        needle,
        "  product-settings:\n"
        "    feature-enabled: true\n"
        "  auth:\n",
    ),
    encoding="utf-8",
)
PY
bash "${T8}/scripts/remove-cache-management.sh" --apply >/dev/null
assert_absent "${T8}/backend/cache-management"
assert_absent "${T8}/backend/application/src/main/resources/ehcache.xml"
assert_absent "${T8}/backend/migrations/src/main/resources/db/changelog/changes/0003-cache-invalidation.xml"
assert_not_contains "${T8}/backend/pom.xml" "<module>cache-management</module>"
assert_not_contains "${T8}/backend/service/pom.xml" "<artifactId>cache-management</artifactId>"
assert_not_contains "${T8}/backend/application/pom.xml" "<artifactId>hibernate-jcache</artifactId>"
assert_not_contains "${T8}/backend/application/src/main/resources/application.yml" "use_second_level_cache"
assert_contains \
  "${T8}/backend/application/src/main/resources/application.yml" \
  "product-settings:"
assert_contains \
  "${T8}/backend/application/src/main/resources/application.yml" \
  "feature-enabled: true"
STRUCTURE_LINT_ALLOW_SAMPLE=1 VERIFY_ROOT="${T8}" bash "${T8}/scripts/structure-lint.sh" >/dev/null
VERIFY_ROOT="${T8}" bash "${T8}/scripts/verify-gates.sh" >/dev/null

trap - EXIT
rm -rf "${T8}"

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "==> test-materialize-project: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ] && exit 0 || exit 1
