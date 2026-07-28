#!/usr/bin/env bash
# Idempotently adds a <dependency> block to the <dependencyManagement> section
# of a Maven POM file.
#
# Usage: add-managed-dependency.sh <pom-file> <groupId> <artifactId> [version] [scope] [type]
#
# If version/scope/type are empty strings or omitted they are not emitted.
set -euo pipefail

POM_FILE="${1:?Usage: add-managed-dependency.sh <pom-file> <groupId> <artifactId> [version] [scope] [type]}"
GROUP_ID="${2:?Usage: add-managed-dependency.sh <pom-file> <groupId> <artifactId> [version] [scope] [type]}"
ARTIFACT_ID="${3:?Usage: add-managed-dependency.sh <pom-file> <groupId> <artifactId> [version] [scope] [type]}"
VERSION="${4:-}"
SCOPE="${5:-}"
DEP_TYPE="${6:-}"

# Check if dependency already present in <dependencyManagement>.
if POM_FILE="$POM_FILE" GROUP_ID="$GROUP_ID" ARTIFACT_ID="$ARTIFACT_ID" python3 - << 'PYEOF'
import os, sys
import xml.etree.ElementTree as ET

pom  = os.environ['POM_FILE']
gid  = os.environ['GROUP_ID']
aid  = os.environ['ARTIFACT_ID']
NS   = 'http://maven.apache.org/POM/4.0.0'

tree = ET.parse(pom)
root = tree.getroot()
dm   = root.find(f'{{{NS}}}dependencyManagement')
if dm is not None:
    deps = dm.find(f'{{{NS}}}dependencies')
    if deps is not None:
        for dep in deps.findall(f'{{{NS}}}dependency'):
            g = dep.find(f'{{{NS}}}groupId')
            a = dep.find(f'{{{NS}}}artifactId')
            if g is not None and a is not None:
                if g.text and g.text.strip() == gid and a.text and a.text.strip() == aid:
                    sys.exit(0)
sys.exit(1)
PYEOF
then
    echo "[add-managed-dependency] $GROUP_ID:$ARTIFACT_ID already in dependencyManagement of $POM_FILE — skipping"
    exit 0
fi

# Build the dependency XML block.
DEP_BLOCK="            <dependency>\n                <groupId>${GROUP_ID}<\/groupId>\n                <artifactId>${ARTIFACT_ID}<\/artifactId>"
if [ -n "$VERSION" ]; then
    DEP_BLOCK="${DEP_BLOCK}\n                <version>${VERSION}<\/version>"
fi
if [ -n "$SCOPE" ]; then
    DEP_BLOCK="${DEP_BLOCK}\n                <scope>${SCOPE}<\/scope>"
fi
if [ -n "$DEP_TYPE" ]; then
    DEP_BLOCK="${DEP_BLOCK}\n                <type>${DEP_TYPE}<\/type>"
fi
DEP_BLOCK="${DEP_BLOCK}\n            <\/dependency>"

# Insert before the closing </dependencies> that is inside <dependencyManagement>.
# Strategy: find the first </dependencies> after <dependencyManagement> and insert before it.
python3 - << PYEOF
import os, re

pom_path = """$POM_FILE"""
group = """$GROUP_ID"""
artifact = """$ARTIFACT_ID"""
version  = """$VERSION"""
scope    = """$SCOPE"""
dep_type = """$DEP_TYPE"""

with open(pom_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Build insertion block.
lines = ['            <dependency>',
         f'                <groupId>{group}</groupId>',
         f'                <artifactId>{artifact}</artifactId>']
if version:
    lines.append(f'                <version>{version}</version>')
if scope:
    lines.append(f'                <scope>{scope}</scope>')
if dep_type:
    lines.append(f'                <type>{dep_type}</type>')
lines.append('            </dependency>')
block = '\n'.join(lines)

# Find <dependencyManagement> region and insert before its closing </dependencies>.
dm_start = content.find('<dependencyManagement>')
if dm_start == -1:
    raise SystemExit('No <dependencyManagement> found in ' + pom_path)
dm_end = content.find('</dependencyManagement>', dm_start)
region = content[dm_start:dm_end]
close_deps = region.rfind('</dependencies>')
if close_deps == -1:
    raise SystemExit('No </dependencies> inside <dependencyManagement>')
insert_at = dm_start + close_deps
new_content = content[:insert_at] + block + '\n' + content[insert_at:]

with open(pom_path, 'w', encoding='utf-8') as f:
    f.write(new_content)
PYEOF

echo "[add-managed-dependency] Added $GROUP_ID:$ARTIFACT_ID to dependencyManagement in $POM_FILE"
