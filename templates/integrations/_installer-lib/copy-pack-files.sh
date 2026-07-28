#!/usr/bin/env bash
# Copies Java sources from a pack template into external-services.
# Substitutes PACKAGE_REPLACE_ME in paths and file content; preserves user edits
# unless PACK_INSTALL_FORCE=1.
#
# Usage: copy-pack-files.sh <pack-src-dir> <dest-dir> [project-root]
set -euo pipefail

PACK_SRC="${1:?Usage: copy-pack-files.sh <pack-src-dir> <dest-dir> [project-root]}"
DEST_DIR="${2:?Usage: copy-pack-files.sh <pack-src-dir> <dest-dir> [project-root]}"
PROJECT_ROOT="${3:-}"
FORCE="${PACK_INSTALL_FORCE:-0}"

if [ ! -d "$PACK_SRC" ]; then
    echo "[copy-pack-files] ERROR: pack source directory not found: $PACK_SRC" >&2
    exit 1
fi

GROUP_ID=""
if [ -n "${PROJECT_ROOT}" ] && [ -f "${PROJECT_ROOT}/backend/pom.xml" ]; then
    BACKEND_POM="${PROJECT_ROOT}/backend/pom.xml"
    export BACKEND_POM
    GROUP_ID="$(python3 - << 'PYEOF'
import os, xml.etree.ElementTree as ET
NS = 'http://maven.apache.org/POM/4.0.0'
tree = ET.parse(os.environ['BACKEND_POM'])
el = tree.getroot().find(f'{{{NS}}}groupId')
print(el.text.strip() if el is not None and el.text else '')
PYEOF
)"
fi

substitute_text() {
    local content="$1"
    if [ -n "${GROUP_ID}" ] && [ "${GROUP_ID}" != "PACKAGE_REPLACE_ME" ]; then
        printf '%s' "${content}" | sed "s/PACKAGE_REPLACE_ME/${GROUP_ID}/g"
    else
        printf '%s' "${content}"
    fi
}

substitute_path() {
    local rel="$1"
    if [ -n "${GROUP_ID}" ] && [ "${GROUP_ID}" != "PACKAGE_REPLACE_ME" ]; then
        printf '%s' "${rel}" | sed "s/PACKAGE_REPLACE_ME/${GROUP_ID}/g"
    else
        printf '%s' "${rel}"
    fi
}

CONFLICTS=0
COPIED=0
UNCHANGED=0

while IFS= read -r -d '' src_file; do
    rel="${src_file#"${PACK_SRC}/"}"
    rel="$(substitute_path "${rel}")"
    dest_file="${DEST_DIR}/${rel}"
    dest_parent="$(dirname "$dest_file")"
    expected="$(substitute_text "$(cat "${src_file}")")"

    if [ -f "$dest_file" ]; then
        if [ "$(cat "${dest_file}")" = "${expected}" ]; then
            echo "[copy-pack-files] unchanged: ${rel}"
            UNCHANGED=$((UNCHANGED + 1))
            continue
        fi
        if [ "${FORCE}" != "1" ]; then
            echo "[copy-pack-files] CONFLICT: ${dest_file} diverged from pack template (set PACK_INSTALL_FORCE=1 to overwrite)" >&2
            CONFLICTS=$((CONFLICTS + 1))
            continue
        fi
        echo "[copy-pack-files] overwrite: ${rel}" >&2
    fi

    mkdir -p "$dest_parent"
    printf '%s' "${expected}" > "${dest_file}"
    echo "[copy-pack-files] copied: ${rel}"
    COPIED=$((COPIED + 1))
done < <(find "$PACK_SRC" -type f -print0)

if [ "${CONFLICTS}" -gt 0 ]; then
    echo "[copy-pack-files] ERROR: ${CONFLICTS} conflict(s) — installation aborted" >&2
    exit 1
fi

if [ -n "${GROUP_ID}" ] && [ "${GROUP_ID}" != "PACKAGE_REPLACE_ME" ]; then
    echo "[copy-pack-files] applied package ${GROUP_ID} (${COPIED} copied, ${UNCHANGED} unchanged)"
else
    echo "[copy-pack-files] done (${COPIED} copied, ${UNCHANGED} unchanged)"
fi
