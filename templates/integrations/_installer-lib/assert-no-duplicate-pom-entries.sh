#!/usr/bin/env bash
# Scans all pom.xml files under a project root and fails if the same full
# Maven dependency coordinate appears more than once in <dependencies> or
# <dependencyManagement> section.
#
# Usage: assert-no-duplicate-pom-entries.sh <project-root>
set -euo pipefail

PROJECT_ROOT="${1:?Usage: assert-no-duplicate-pom-entries.sh <project-root>}"

FAILURES=0

while IFS= read -r -d '' pom; do
    result=$(PROJECT_ROOT="$PROJECT_ROOT" POM="$pom" python3 - << 'PYEOF'
import os, sys, collections
import xml.etree.ElementTree as ET

pom  = os.environ['POM']
NS   = 'http://maven.apache.org/POM/4.0.0'

try:
    tree = ET.parse(pom)
except ET.ParseError as e:
    print(f"PARSE_ERROR:{pom}:{e}", flush=True)
    sys.exit(0)

root = tree.getroot()
sections = []

# Top-level <dependencies>
top_deps = root.find(f'{{{NS}}}dependencies')
if top_deps is not None:
    sections.append(('dependencies', top_deps))

# <dependencyManagement><dependencies>
dm = root.find(f'{{{NS}}}dependencyManagement')
if dm is not None:
    dm_deps = dm.find(f'{{{NS}}}dependencies')
    if dm_deps is not None:
        sections.append(('dependencyManagement', dm_deps))

for section_name, deps_el in sections:
    counter = collections.Counter()
    for dep in deps_el.findall(f'{{{NS}}}dependency'):
        def text(name):
            node = dep.find(f'{{{NS}}}{name}')
            return (node.text or '').strip() if node is not None else ''

        group_id = text('groupId')
        artifact_id = text('artifactId')
        if not artifact_id:
            continue
        coordinate = (
            group_id,
            artifact_id,
            text('type') or 'jar',
            text('classifier'),
            text('scope'),
        )
        counter[coordinate] += 1
    for coordinate, count in counter.items():
        if count > 1:
            label = ':'.join(part or '-' for part in coordinate)
            print(f"DUPLICATE:{pom}:{section_name}:{label}:count={count}", flush=True)
PYEOF
)

    if [ -n "$result" ]; then
        echo "$result" >&2
        FAILURES=$((FAILURES + 1))
    fi
done < <(find "$PROJECT_ROOT/backend" -name "pom.xml" -not -path "*/target/*" -print0 2>/dev/null)

if [ "$FAILURES" -gt 0 ]; then
    echo "[assert-no-duplicate-pom-entries] FAILED: $FAILURES pom(s) have duplicate dependency entries" >&2
    exit 1
fi

echo "[assert-no-duplicate-pom-entries] OK — no duplicate POM dependency entries found"
