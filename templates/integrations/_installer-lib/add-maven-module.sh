#!/usr/bin/env bash
# Idempotently adds a <module> entry to a Maven POM file.
# Usage: add-maven-module.sh <pom-file> <module-name>
set -euo pipefail

POM_FILE="${1:?Usage: add-maven-module.sh <pom-file> <module-name>}"
MODULE_NAME="${2:?Usage: add-maven-module.sh <pom-file> <module-name>}"

# Check if module already present using Python3 structured XML parse.
if POM_FILE="$POM_FILE" MODULE_NAME="$MODULE_NAME" python3 - << 'PYEOF'
import os, sys
import xml.etree.ElementTree as ET

pom = os.environ['POM_FILE']
module = os.environ['MODULE_NAME']
NS = 'http://maven.apache.org/POM/4.0.0'

tree = ET.parse(pom)
root = tree.getroot()
modules_el = root.find(f'{{{NS}}}modules')
if modules_el is not None:
    for m in modules_el.findall(f'{{{NS}}}module'):
        if m.text and m.text.strip() == module:
            sys.exit(0)
sys.exit(1)
PYEOF
then
    echo "[add-maven-module] <module>$MODULE_NAME</module> already present in $POM_FILE — skipping"
    exit 0
fi

# Insert the new module entry before the closing </modules> tag.
awk -v mod="$MODULE_NAME" '
    /<\/modules>/ { print "        <module>" mod "<\/module>" }
    { print }
' "$POM_FILE" > "${POM_FILE}.tmp"
mv "${POM_FILE}.tmp" "$POM_FILE"
echo "[add-maven-module] Added <module>$MODULE_NAME</module> to $POM_FILE"
