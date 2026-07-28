#!/usr/bin/env bash
# Integration pack CI test driver.
#
# For each pack, the driver:
#   1. Materializes a clean temporary project.
#   2. Asserts external-services does NOT exist before first install.
#   3. Runs install.sh.
#   4. Asserts external-services exists with real source files.
#   5. Asserts backend/pom.xml has <module>external-services</module> exactly once.
#   6. Asserts no PACKAGE_REPLACE_ME remains in external-services sources.
#   7. Runs Maven verify (skipped when JAVA_HOME is not set).
#   8. Runs the same install.sh again (idempotency check).
#   9. Calls assert-no-duplicate-pom-entries.sh.
#  10. Prints pass/fail summary.
#
# Usage:
#   bash templates/integrations/test-install-packs.sh
#   JAVA_HOME=/usr/lib/jvm/java-21 bash templates/integrations/test-install-packs.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INTEGRATIONS_DIR="${REPO_ROOT}/templates/integrations"
SCAFFOLD_ROOT="${REPO_ROOT}/templates/generated-project/scaffold"
LIB_DIR="${INTEGRATIONS_DIR}/_installer-lib"

PASS=0
FAIL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}  PASS${NC} $*"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}  FAIL${NC} $*"; FAIL=$((FAIL + 1)); }
info() { echo -e "${YELLOW}  INFO${NC} $*"; }

materialize_project() {
    local dest="$1"
    local app_name="${2:-testapp}"
    rm -rf "$dest"
    mkdir -p "$dest"

    SCAFFOLD_ROOT="$SCAFFOLD_ROOT" \
    MATERIALIZE_DEST="$dest" \
    TEMPLATE_REPO_ROOT="$REPO_ROOT" \
        bash "${SCAFFOLD_ROOT}/scripts/materialize-project.sh" "$app_name" 2>&1 | \
        sed 's/^/    /'
}

run_maven() {
    local project_root="$1"
    if [ -z "${JAVA_HOME:-}" ]; then
        info "JAVA_HOME not set - skipping Maven verify"
        return 0
    fi
    if ! command -v mvn >/dev/null 2>&1; then
        fail "mvn not found on PATH (JAVA_HOME=${JAVA_HOME})"
        return 1
    fi
    local goal="${MAVEN_GOAL:-verify}"
    local local_repo_arg=""
    if [ -n "${MAVEN_REPO_LOCAL:-}" ]; then
        local_repo_arg="-Dmaven.repo.local=${MAVEN_REPO_LOCAL}"
    fi
    info "Running Maven ${goal} (JAVA_HOME=${JAVA_HOME})..."
    JAVA_HOME="${JAVA_HOME}" mvn -f "${project_root}/backend/pom.xml" \
        ${local_repo_arg} \
        ${MAVEN_CLI_OPTS:-} \
        -DskipTests \
        -Dgit-commit-id.skip=true \
        "${goal}" 2>&1 | tail -20 | sed 's/^/    /'
}

assert_no_external_services() {
    local project_root="$1"
    if [ -d "${project_root}/backend/external-services" ]; then
        fail "external-services exists BEFORE install in $project_root"
    else
        pass "external-services absent before first install"
    fi
}

assert_external_services_exists() {
    local project_root="$1"
    if [ -d "${project_root}/backend/external-services/src" ]; then
        pass "external-services/src exists after install"
    else
        fail "external-services/src missing after install in $project_root"
    fi
}

assert_external_services_has_java_files() {
    local project_root="$1"
    local count
    count=$(find "${project_root}/backend/external-services/src" -name "*.java" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        pass "external-services contains $count Java source file(s)"
    else
        fail "external-services has no Java source files after install"
    fi
}

assert_no_package_placeholder() {
    local project_root="$1"
    local count
    count=$(find "${project_root}/backend/external-services" -name '*PACKAGE_REPLACE_ME*' 2>/dev/null | wc -l | tr -d ' ') || count=0
    local java_count
    java_count=$(find "${project_root}/backend/external-services/src" -name '*.java' -print0 2>/dev/null \
        | xargs -0 grep -l 'PACKAGE_REPLACE_ME' 2>/dev/null | wc -l | tr -d ' ') || java_count=0
    if [ "$count" -eq 0 ] && [ "$java_count" -eq 0 ]; then
        pass "no PACKAGE_REPLACE_ME in external-services paths or sources"
    else
        fail "PACKAGE_REPLACE_ME remains (${count} path(s), ${java_count} file(s))"
    fi
}

assert_module_present_exactly_once() {
    local project_root="$1"
    local pom="${project_root}/backend/pom.xml"
    local count
    count=$(grep -c '<module>external-services</module>' "$pom" 2>/dev/null || echo 0)
    if [ "$count" -eq 1 ]; then
        pass "<module>external-services</module> appears exactly once in backend/pom.xml"
    else
        fail "<module>external-services</module> count=$count in backend/pom.xml (expected 1)"
    fi
}

assert_no_duplicate_pom_entries() {
    local project_root="$1"
    if bash "${LIB_DIR}/assert-no-duplicate-pom-entries.sh" "$project_root" 2>&1 | \
            sed 's/^/    /'; then
        pass "No duplicate POM dependency entries"
    else
        fail "Duplicate POM dependency entries detected"
    fi
}

assert_verify_gates() {
    local project_root="$1"
    if (cd "$project_root" && bash scripts/verify-gates.sh) 2>&1 | sed 's/^/    /'; then
        pass "verify-gates passed"
    else
        fail "verify-gates failed"
    fi
}

assert_http_foundation_not_duplicated() {
    local project_root="$1"
    local http_props_count
    http_props_count=$(find "${project_root}/backend/external-services/src" \
        -name "PooledHttpClientProperties.java" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$http_props_count" -eq 1 ]; then
        pass "PooledHttpClientProperties.java appears exactly once (HTTP foundation not duplicated)"
    else
        fail "PooledHttpClientProperties.java count=$http_props_count (expected 1)"
    fi
}

assert_observability_wiring() {
    local project_root="$1"
    local pom="${project_root}/backend/external-services/pom.xml"
    local factory
    factory=$(find "${project_root}/backend/external-services/src/main/java" \
        -name 'PooledRestClientFactory.java' -print -quit 2>/dev/null)
    if grep -q '<artifactId>lombok</artifactId>' "$pom" \
        && grep -q '<artifactId>observability</artifactId>' "$pom"; then
        pass "external-services declares Lombok and reusable observability"
    else
        fail "external-services must declare Lombok and observability dependencies"
    fi
    if [ -n "$factory" ] \
        && grep -Fq 'new ExternalClientMetricsInterceptor(name, meterRegistry)' "$factory"; then
        pass "PooledRestClientFactory registers ExternalClientMetricsInterceptor"
    else
        fail "PooledRestClientFactory missing ExternalClientMetricsInterceptor"
    fi
    if [ -n "$factory" ] \
        && grep -Fq 'new LogbookClientHttpRequestInterceptor(logbook)' "$factory"; then
        pass "PooledRestClientFactory registers LogbookClientHttpRequestInterceptor"
    else
        fail "PooledRestClientFactory missing LogbookClientHttpRequestInterceptor"
    fi
}

assert_runtime_assembly_wiring() {
    local project_root="$1"
    if PROJECT_ROOT="$project_root" python3 - <<'PYEOF'
import os
import sys
import xml.etree.ElementTree as ET

ns = {"m": "http://maven.apache.org/POM/4.0.0"}
root = os.environ["PROJECT_ROOT"]

def dependency_scope(pom_path):
    tree = ET.parse(pom_path)
    for dependency in tree.findall("./m:dependencies/m:dependency", ns):
        group = dependency.findtext("m:groupId", namespaces=ns)
        artifact = dependency.findtext("m:artifactId", namespaces=ns)
        if group == "${project.groupId}" and artifact == "external-services":
            return dependency.findtext("m:scope", default="compile", namespaces=ns)
    return None

application_scope = dependency_scope(
    os.path.join(root, "backend", "application", "pom.xml")
)
service_scope = dependency_scope(
    os.path.join(root, "backend", "service", "pom.xml")
)
sys.exit(0 if application_scope == "runtime" and service_scope is None else 1)
PYEOF
    then
        pass "application owns external-services runtime assembly; service has no unused adapter edge"
    else
        fail "external-services must be runtime-scoped in application and absent from service"
    fi
}

test_pack() {
    local pack_name="$1"
    local pack_dir="${INTEGRATIONS_DIR}/${pack_name}"

    echo ""
    echo "==================================================="
    echo "  Testing pack: $pack_name"
    echo "==================================================="

    local tmp_dir tmp_project
    tmp_dir="$(mktemp -d)"
    tmp_project="${tmp_dir}/project"

    echo ""
    info "Materializing clean project at ${tmp_project} ..."
    if materialize_project "$tmp_project" "testapp"; then
        pass "Project materialized"
    else
        fail "Project materialization failed for $pack_name"
        rm -rf "${tmp_dir}"
        return
    fi

    echo ""
    info "--- Before first install ---"
    assert_no_external_services "$tmp_project"

    echo ""
    info "--- First install ---"
    if PROJECT_ROOT="$tmp_project" bash "${pack_dir}/install.sh" 2>&1 | \
            sed 's/^/    /'; then
        pass "install.sh exited 0"
    else
        fail "install.sh failed for $pack_name"
        rm -rf "${tmp_dir}"
        return
    fi

    echo ""
    info "--- Post-install assertions ---"
    assert_external_services_exists "$tmp_project"
    assert_external_services_has_java_files "$tmp_project"
    assert_module_present_exactly_once "$tmp_project"
    assert_no_package_placeholder "$tmp_project"
    assert_observability_wiring "$tmp_project"
    assert_runtime_assembly_wiring "$tmp_project"
    assert_verify_gates "$tmp_project"

    echo ""
    info "--- Maven verify (first install) ---"
    run_maven "$tmp_project" || fail "Maven verify failed after first install of $pack_name"

    echo ""
    info "--- Second install (idempotency) ---"
    if PROJECT_ROOT="$tmp_project" bash "${pack_dir}/install.sh" 2>&1 | \
            sed 's/^/    /'; then
        pass "Second install.sh run exited 0"
    else
        fail "Second install.sh run failed for $pack_name"
    fi

    echo ""
    info "--- Post-idempotency assertions ---"
    assert_module_present_exactly_once "$tmp_project"
    assert_no_duplicate_pom_entries "$tmp_project"
    assert_verify_gates "$tmp_project"

    rm -rf "${tmp_dir}"
}

test_two_packs_no_duplication() {
    echo ""
    echo "==================================================="
    echo "  Testing HTTP foundation is not duplicated when"
    echo "  installing claude then openai"
    echo "==================================================="

    local tmp_dir tmp_project
    tmp_dir="$(mktemp -d)"
    tmp_project="${tmp_dir}/project"

    info "Materializing clean project at ${tmp_project} ..."
    if ! materialize_project "$tmp_project" "testapp" 2>&1 | sed 's/^/    /'; then
        fail "Project materialization failed for two-pack test"
        rm -rf "${tmp_dir}"
        return
    fi

    info "Installing claude pack..."
    PROJECT_ROOT="$tmp_project" bash "${INTEGRATIONS_DIR}/claude/install.sh" \
        2>&1 | sed 's/^/    /' || { fail "Claude install failed"; rm -rf "${tmp_dir}"; return; }

    info "Installing openai pack..."
    PROJECT_ROOT="$tmp_project" bash "${INTEGRATIONS_DIR}/openai/install.sh" \
        2>&1 | sed 's/^/    /' || { fail "OpenAI install failed"; rm -rf "${tmp_dir}"; return; }

    echo ""
    info "--- Assertions: both packs installed, foundation not duplicated ---"
    assert_module_present_exactly_once "$tmp_project"
    assert_no_duplicate_pom_entries "$tmp_project"
    assert_http_foundation_not_duplicated "$tmp_project"
    assert_observability_wiring "$tmp_project"
    assert_runtime_assembly_wiring "$tmp_project"
    assert_verify_gates "$tmp_project"

    if [ -n "$(find "${tmp_project}/backend/external-services/src" -name "ClaudeClient.java" -print -quit)" ]; then
        pass "ClaudeClient.java present after two-pack install"
    else
        fail "ClaudeClient.java missing after two-pack install"
    fi
    if [ -n "$(find "${tmp_project}/backend/external-services/src" -name "OpenAiClient.java" -print -quit)" ]; then
        pass "OpenAiClient.java present after two-pack install"
    else
        fail "OpenAiClient.java missing after two-pack install"
    fi

    echo ""
    info "--- Maven verify (two-pack install) ---"
    run_maven "$tmp_project" || fail "Maven verify failed after two-pack install"

    rm -rf "${tmp_dir}"
}

echo ""
echo "Integration Pack CI Test Driver"
echo "  SCAFFOLD_ROOT: $SCAFFOLD_ROOT"
echo "  JAVA_HOME:     ${JAVA_HOME:-<not set - Maven skipped>}"

for pack in _http-client-foundation claude openai google-workspace bigquery; do
    test_pack "$pack"
done

test_two_packs_no_duplication

echo ""
echo "---------------------------------------------------"
echo "  Results: ${PASS} PASS  ${FAIL} FAIL"
echo "---------------------------------------------------"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
echo -e "${GREEN}All pack CI tests passed.${NC}"
