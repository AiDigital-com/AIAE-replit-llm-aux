#!/usr/bin/env bash
# Appends integration config under the existing top-level `app:` key in
# application.yml (never adds a duplicate root `app:` block).
#
# Usage: append-app-external-yml.sh <application.yml> <provider-key> <stub-file>
#
# <provider-key>  e.g. http, claude, openai, bigquery, google-workspace
# <stub-file>     YAML fragment with 4-space indent (provider block only), e.g.:
#                   claude:
#                     enabled: ${CLAUDE_ENABLED:false}
set -euo pipefail

APP_YML="${1:?Usage: append-app-external-yml.sh <application.yml> <provider> <stub-file>}"
PROVIDER="${2:?provider key required}"
STUB_FILE="${3:?stub file required}"

if [ ! -f "${APP_YML}" ]; then
    echo "[append-app-external-yml] ERROR: ${APP_YML} not found" >&2
    exit 1
fi
if [ ! -f "${STUB_FILE}" ]; then
    echo "[append-app-external-yml] ERROR: ${STUB_FILE} not found" >&2
    exit 1
fi

if grep -qE "^[[:space:]]{4}${PROVIDER}:" "${APP_YML}" 2>/dev/null; then
    echo "[append-app-external-yml] app.external.${PROVIDER} already present — skipping"
    exit 0
fi

python3 - "${APP_YML}" "${PROVIDER}" "${STUB_FILE}" << 'PYEOF'
import sys
from pathlib import Path

app_yml = Path(sys.argv[1])
provider = sys.argv[2]
stub = Path(sys.argv[3]).read_text().rstrip() + "\n"
text = app_yml.read_text()

if f"    {provider}:" in text:
    sys.exit(0)

if "  external:" not in text:
    block = "  external:\n" + stub
else:
    block = stub

comment = f"\n# Integration pack: app.external.{provider}\n"
app_yml.write_text(text.rstrip() + comment + block)
print(f"[append-app-external-yml] merged app.external.{provider} into {app_yml}")
PYEOF
