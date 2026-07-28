#!/usr/bin/env bash
#
# strip-scaffold-samples.sh — one-shot removal of the scaffold's reference
# sample aggregate. Runs as part of landing the FIRST real aggregate, after
# the agent has read the sample files for canonical layout reference.
#
# What it deletes:
#   - backend/domain/src/main/java/<base>/domain/sample/
#   - backend/service/src/main/java/<base>/service/sample/
#   - backend/service/src/main/java/<base>/service/mappers/sample/
#   - backend/service/src/test/java/<base>/service/sample/
#   - backend/service/src/test/java/<base>/service/mappers/sample/
#   - backend/migrations/src/main/resources/db/changelog/changes/0002-sample-reference.xml
# What it edits:
#   - backend/migrations/src/main/resources/db/changelog/db.changelog-master.xml
#     (removes the <include> line for 0002-sample-reference.xml and its
#     surrounding SCAFFOLD-EXAMPLE comment block)
#
# Idempotent — safe to re-run. Exits 0 even if nothing was left to remove.
#
# Usage (from project root):
#   bash scripts/strip-scaffold-samples.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${ROOT}"

SAMPLE_CHANGELOG="backend/migrations/src/main/resources/db/changelog/changes/0002-sample-reference.xml"
MASTER_CHANGELOG="backend/migrations/src/main/resources/db/changelog/db.changelog-master.xml"

removed_any=false

remove_sample_dirs() {
    local kind="$1"   # domain or service
    local scope="$2"  # main or test
    local base="backend/${kind}/src/${scope}/java"
    while IFS= read -r path; do
        rm -rf "${path}"
        echo "    removed ${path}"
        removed_any=true
    done < <(find "${base}" -type d -path "*/${kind}/sample" 2>/dev/null)
}

echo "==> Removing scaffold sample aggregate"
remove_sample_dirs "domain" "main"
remove_sample_dirs "service" "main"
remove_sample_dirs "service" "test"

while IFS= read -r path; do
    rm -rf "${path}"
    echo "    removed ${path}"
    removed_any=true
done < <(find backend/service/src/main/java backend/service/src/test/java -type d -path '*/service/mappers/sample' 2>/dev/null)

if [ -f "${SAMPLE_CHANGELOG}" ]; then
    rm -f "${SAMPLE_CHANGELOG}"
    echo "    removed ${SAMPLE_CHANGELOG}"
    removed_any=true
fi

if [ -f "${MASTER_CHANGELOG}" ] && grep -q '0002-sample-reference.xml' "${MASTER_CHANGELOG}"; then
    echo "==> Stripping sample-reference <include> from db.changelog-master.xml"
    tmp="${MASTER_CHANGELOG}.tmp"
    # The scaffold note opens with a lone `<!--` on the line *before* the
    # SCAFFOLD EXAMPLE text. Skipping from the text onward left that opener
    # behind and consumed the closing `-->`, producing an unterminated comment
    # and a changelog Liquibase refuses to parse. So hold a lone `<!--` until we
    # know whether it opens the scaffold note, and drop or restore it.
    awk '
      pending && /SCAFFOLD EXAMPLE include/ { pending=0; skip=1; next }
      pending                               { print held; pending=0 }
      !skip && /^[[:space:]]*<!--[[:space:]]*$/ { held=$0; pending=1; next }
      skip && /-->/                         { skip=0; next }
      skip                                  { next }
      /0002-sample-reference\.xml/          { next }
      { print }
      END { if (pending) print held }
    ' "${MASTER_CHANGELOG}" > "${tmp}"

    # Never leave a half-edited changelog behind: the app will not boot.
    if command -v python3 >/dev/null 2>&1; then
      python3 -c 'import sys,xml.dom.minidom as m; m.parse(sys.argv[1])' "${tmp}" 2>/dev/null \
        || { rm -f "${tmp}"; echo "strip-scaffold-samples: refusing to write malformed ${MASTER_CHANGELOG}" >&2; exit 1; }
    fi
    mv "${tmp}" "${MASTER_CHANGELOG}"
    echo "    edited ${MASTER_CHANGELOG}"
    removed_any=true
fi

if $removed_any; then
    echo "==> Done. Sample aggregate stripped."
    # The removal is mechanical and complete, so it belongs in its own commit.
    # Left uncommitted it rides along in the first feature diff, and a reviewer then
    # reads scaffold cleanup and new behaviour as one change. Not committed here on
    # purpose: this script does not write to anyone's history uninvited.
    if git rev-parse --git-dir >/dev/null 2>&1; then
        echo ""
        echo "    Commit this on its own, before the first feature diff:"
        echo "      git add -A && git commit -m 'Remove scaffold sample aggregate'"
    fi
else
    echo "==> Nothing to remove — sample aggregate already stripped."
fi
