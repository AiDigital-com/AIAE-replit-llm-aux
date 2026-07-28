#!/usr/bin/env bash
# Fixture tests for scaffold/scripts/lib/check-liquibase-preconditions.sh.
#
# This gate had no test of any kind, and a defect in exactly its area reached
# main: strip-scaffold-samples.sh left an unterminated XML comment, so Liquibase
# refused to parse the changelog in every stripped project. The scanner does
# report malformed XML — it simply never ran against a stripped project, because
# that variant is not built. The malformed-XML case below is that bug, pinned.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "${HERE}/../../.." && pwd)"
SCAFFOLD="${REPO}/templates/generated-project/scaffold"
GATE="${SCAFFOLD}/scripts/lib/check-liquibase-preconditions.sh"
. "${HERE}/../lib/assert.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

CHANGELOG_REL="backend/migrations/src/main/resources/db/changelog"
run_gate() { VERIFY_ROOT="$1" bash "${GATE}"; }

synth() {
  local name="$1" dir="${WORK}/$1"
  rm -rf "$dir"; mkdir -p "${dir}/${CHANGELOG_REL}/changes"
  printf '%s' "$dir"
}

good_changeset() {
  cat > "$1" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog xmlns="http://www.liquibase.org/xml/ns/dbchangelog">
    <changeSet id="0001-widgets" author="aiae">
        <preConditions onFail="MARK_RAN">
            <not><tableExists tableName="widgets"/></not>
        </preConditions>
        <createTable tableName="widgets">
            <column name="id" type="BIGINT"/>
        </createTable>
    </changeSet>
</databaseChangeLog>
EOF
}

echo "==> positive"

F="$(synth valid)"
good_changeset "${F}/${CHANGELOG_REL}/changes/0001-widgets.xml"
gate_accepts "changeSet with direct preConditions" "${F}" -- run_gate "${F}"

echo "==> violation classes"

F="$(synth missing-preconditions)"
cat > "${F}/${CHANGELOG_REL}/changes/0002-orders.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog xmlns="http://www.liquibase.org/xml/ns/dbchangelog">
    <changeSet id="0002-orders" author="aiae">
        <createTable tableName="orders">
            <column name="id" type="BIGINT"/>
        </createTable>
    </changeSet>
</databaseChangeLog>
EOF
gate_rejects "changeSet without preConditions" "${F}" \
  "must declare direct <preConditions>" -- run_gate "${F}"

# The exact shape of the defect that shipped: a comment opened and never closed,
# which makes the whole changelog unparseable.
F="$(synth unterminated-xml-comment)"
good_changeset "${F}/${CHANGELOG_REL}/changes/0001-widgets.xml"
cat > "${F}/${CHANGELOG_REL}/changes/0003-stripped.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog xmlns="http://www.liquibase.org/xml/ns/dbchangelog">
    <!-- sample aggregate removed by strip-scaffold-samples.sh
    <changeSet id="0003-samples" author="aiae">
        <preConditions onFail="MARK_RAN"><not><tableExists tableName="samples"/></not></preConditions>
    </changeSet>
</databaseChangeLog>
EOF
gate_rejects "unterminated XML comment leaves the changelog unparseable" "${F}" \
  "invalid XML" -- run_gate "${F}"

# A changeSet nested below the top level must still be checked; the scanner walks
# the whole tree rather than only direct children.
F="$(synth nested-changeset-missing-preconditions)"
cat > "${F}/${CHANGELOG_REL}/changes/0004-nested.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog xmlns="http://www.liquibase.org/xml/ns/dbchangelog">
    <changeSet id="0004-outer" author="aiae">
        <preConditions onFail="MARK_RAN"><not><tableExists tableName="outer"/></not></preConditions>
        <createTable tableName="outer"><column name="id" type="BIGINT"/></createTable>
    </changeSet>
    <databaseChangeLog>
        <changeSet id="0004-inner" author="aiae">
            <createTable tableName="inner"><column name="id" type="BIGINT"/></createTable>
        </changeSet>
    </databaseChangeLog>
</databaseChangeLog>
EOF
gate_rejects "nested changeSet without preConditions" "${F}" \
  "id=0004-inner" -- run_gate "${F}"

echo "==> documented behaviour when there is nothing to scan"

# An absent changelog directory is reported as skipped, not failed. Unlike the
# coverage gate, that is defensible here: a project may legitimately have no
# migrations yet, and a missing directory cannot hide an unchecked changeSet.
F="$(synth changelog-absent)"
rm -rf "${F}/backend"
gate_accepts "absent changelog directory is skipped" "${F}" -- run_gate "${F}"

gate_summary "test-gate-liquibase-preconditions"
