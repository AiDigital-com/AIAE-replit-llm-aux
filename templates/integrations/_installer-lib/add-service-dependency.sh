#!/usr/bin/env bash
# Idempotently adds a <dependency> to backend/service/pom.xml (or a specified pom).
#
# Usage: add-service-dependency.sh <project-root> <groupId> <artifactId> [version] [scope]
#        POM_FILE=path/to/pom.xml add-service-dependency.sh "" <groupId> <artifactId> [version] [scope]
#
# When POM_FILE env var is set, it is used directly (ignoring project-root).
set -euo pipefail

PROJECT_ROOT="${1:?Usage: add-service-dependency.sh <project-root> <groupId> <artifactId> [version] [scope]}"
GROUP_ID="${2:?}"
ARTIFACT_ID="${3:?}"
VERSION="${4:-}"
SCOPE="${5:-}"

TARGET_POM="${POM_FILE:-${PROJECT_ROOT}/backend/service/pom.xml}"

if [ ! -f "$TARGET_POM" ]; then
    echo "[add-service-dependency] ERROR: $TARGET_POM not found" >&2
    exit 1
fi

# Check if dependency already present (anywhere in <dependencies>, not in <dependencyManagement>).
if POM_FILE="$TARGET_POM" GROUP_ID="$GROUP_ID" ARTIFACT_ID="$ARTIFACT_ID" python3 - << 'PYEOF'
import os, sys
import xml.etree.ElementTree as ET

pom  = os.environ['POM_FILE']
gid  = os.environ['GROUP_ID']
aid  = os.environ['ARTIFACT_ID']
NS   = 'http://maven.apache.org/POM/4.0.0'

tree = ET.parse(pom)
root = tree.getroot()

# Look in top-level <dependencies> only (not inside dependencyManagement).
deps_el = root.find(f'{{{NS}}}dependencies')
if deps_el is not None:
    for dep in deps_el.findall(f'{{{NS}}}dependency'):
        g = dep.find(f'{{{NS}}}groupId')
        a = dep.find(f'{{{NS}}}artifactId')
        if g is not None and a is not None:
            if g.text and g.text.strip() == gid and a.text and a.text.strip() == aid:
                sys.exit(0)
sys.exit(1)
PYEOF
then
    echo "[add-service-dependency] $GROUP_ID:$ARTIFACT_ID already in $TARGET_POM — skipping"
    exit 0
fi

# Build insertion block.
python3 - << PYEOF
import os

pom_path  = """$TARGET_POM"""
group     = """$GROUP_ID"""
artifact  = """$ARTIFACT_ID"""
version   = """$VERSION"""
scope     = """$SCOPE"""

with open(pom_path, 'r', encoding='utf-8') as f:
    content = f.read()

lines = ['        <dependency>',
         f'            <groupId>{group}</groupId>',
         f'            <artifactId>{artifact}</artifactId>']
if version:
    lines.append(f'            <version>{version}</version>')
if scope:
    lines.append(f'            <scope>{scope}</scope>')
lines.append('        </dependency>')
block = '\n'.join(lines)

# Insert before the last </dependencies> in file.
idx = content.rfind('</dependencies>')
if idx == -1:
    raise SystemExit('No </dependencies> found in ' + pom_path)
new_content = content[:idx] + block + '\n' + content[idx:]

with open(pom_path, 'w', encoding='utf-8') as f:
    f.write(new_content)
PYEOF

echo "[add-service-dependency] Added $GROUP_ID:$ARTIFACT_ID to $TARGET_POM"
