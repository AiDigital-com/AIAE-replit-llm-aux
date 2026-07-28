#!/usr/bin/env bash
#
# Remove the MVP-only event-logging-to-db feature before engineering handoff.
# Safe annotation/import cleanup is automatic; semantic UsageAttributes or
# custom sink usage blocks and must be removed deliberately by the agent.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

exec python3 "${SCRIPT_DIR}/lib/remove-usage-logging.py" "${PROJECT_ROOT}" "$@"
