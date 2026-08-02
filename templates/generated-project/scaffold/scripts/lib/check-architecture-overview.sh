#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${VERIFY_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
DOC="${ROOT}/docs/architecture-overview.md"

fail() {
  echo "check-architecture-overview: $*" >&2
  exit 1
}

[ -f "${DOC}" ] || fail "missing docs/architecture-overview.md"

required_sections=(
  "Document status"
  "Product and system context"
  "Product-specific evidence"
  "Runtime and deployment"
  "Repository and module boundaries"
  "Primary runtime flows"
  "API and security boundaries"
  "Data ownership and migrations"
  "Caching and consistency"
  "External integrations"
  "Observability and operations"
  "Decisions, constraints, and known risks"
)

for section in "${required_sections[@]}"; do
  grep -Fqx "## ${section}" "${DOC}" \
    || fail "docs/architecture-overview.md is missing required section: ${section}"
done

exact_line_count() {
  grep -Fxc -- "$1" "${DOC}" || true
}

module_row_count() {
  grep -Fc -- "| \`backend/$1\` |" "${DOC}" || true
}

require_repository_owned_evidence() {
  local evidence_kind="$1"
  local evidence_path="$2"

  python3 - "${ROOT}" "${evidence_path}" <<'PY' || \
    fail "${evidence_kind} evidence path escapes the repository through a symlink: ${evidence_path}"
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve(strict=True)
candidate = (root / sys.argv[2]).resolve(strict=True)
try:
    candidate.relative_to(root)
except ValueError:
    raise SystemExit(1)
raise SystemExit(0 if candidate.is_file() else 1)
PY
}

# Keep mechanically managed optional modules truthful in every phase. Removal
# commands update these facts in the same transaction as the source tree.
if [ -d "${ROOT}/backend/event-logging-to-db-feature" ]; then
  [ "$(exact_line_count '- MVP usage telemetry: enabled during MVP')" -eq 1 ] \
    || fail "active MVP telemetry requires exactly one architecture status: MVP usage telemetry: enabled during MVP"
  [ "$(module_row_count 'event-logging-to-db-feature')" -eq 1 ] \
    || fail "active MVP telemetry requires exactly one architecture module-table row"
else
  [ "$(exact_line_count '- MVP usage telemetry: removed')" -eq 1 ] \
    || fail "removed MVP telemetry requires exactly one architecture status: MVP usage telemetry: removed"
  [ "$(module_row_count 'event-logging-to-db-feature')" -eq 0 ] \
    || fail "architecture module table still lists MVP telemetry after removal"
fi

if [ -d "${ROOT}/backend/cache-management" ]; then
  [ "$(exact_line_count '- Cache status: enabled')" -eq 1 ] \
    || fail "active cache-management requires exactly one architecture status: Cache status: enabled"
  [ "$(module_row_count 'cache-management')" -eq 1 ] \
    || fail "active cache-management requires exactly one architecture module-table row"
else
  [ "$(exact_line_count '- Cache status: disabled')" -eq 1 ] \
    || fail "removed cache-management requires exactly one architecture status: Cache status: disabled"
  [ "$(module_row_count 'cache-management')" -eq 0 ] \
    || fail "architecture module table still lists cache-management after it was removed"
fi

# shellcheck source=./coverage-phase.sh
. "${SCRIPT_DIR}/coverage-phase.sh"
phase="$(coverage_phase_read "${ROOT}")" || exit 1
if [ "${phase}" = "engineering" ]; then
  ! grep -Fq "ARCHITECTURE-TODO" "${DOC}" \
    || fail "docs/architecture-overview.md still contains ARCHITECTURE-TODO markers in engineering phase"
  [ "$(exact_line_count '- Lifecycle phase: Engineering')" -eq 1 ] \
    || fail "engineering overview requires exactly one status: Lifecycle phase: Engineering"
  last_verified_count="$(grep -Ec '^- Last verified against: [^[:space:]].*' "${DOC}" || true)"
  [ "${last_verified_count}" -eq 1 ] \
    || fail "engineering overview requires exactly one non-empty Last verified against status"
  if grep -Fqx -- '- Lifecycle phase: MVP' "${DOC}" \
      || grep -Eq 'Last verified against:[[:space:]]*initial scaffold' "${DOC}" \
      || grep -Fq 'user["Product user"]' "${DOC}" \
      || grep -Fq 'external["External systems"]' "${DOC}"; then
    fail "docs/architecture-overview.md still contains generic scaffold facts in engineering phase"
  fi

  for field in "Product capability" "Primary users" "Primary production flow"; do
    field_count="$(grep -Ec "^- ${field}: [^[:space:]].*" "${DOC}" || true)"
    [ "${field_count}" -eq 1 ] \
      || fail "engineering overview requires exactly one non-empty product fact: ${field}"
  done

  evidence_paths=()
  while IFS= read -r evidence_path; do
    evidence_paths+=("${evidence_path}")
  done < <(sed -n 's/^- Evidence path: `\([^`][^`]*\)`$/\1/p' "${DOC}")

  [ "${#evidence_paths[@]}" -ge 2 ] \
    || fail "engineering overview requires at least two implementation evidence paths"

  unique_evidence_count="$(printf '%s\n' "${evidence_paths[@]}" | LC_ALL=C sort -u | awk 'END { print NR }')"
  [ "${unique_evidence_count}" -ge 2 ] \
    || fail "engineering overview requires at least two distinct implementation evidence paths"

  for evidence_path in "${evidence_paths[@]}"; do
    case "${evidence_path}" in
      /*|../*|*/../*|*/..)
        fail "architecture evidence path must stay inside the repository: ${evidence_path}"
        ;;
      frontend/src/*|backend/*/src/*) ;;
      *)
        fail "architecture evidence must point to frontend/src or a backend module src tree: ${evidence_path}"
        ;;
    esac
    [ -f "${ROOT}/${evidence_path}" ] \
      || fail "architecture evidence path does not exist: ${evidence_path}"
    require_repository_owned_evidence "architecture" "${evidence_path}"
  done

  section_evidence="$(python3 - "${DOC}" <<'PY'
import re
import sys
from pathlib import Path

required = (
    "Runtime and deployment",
    "Repository and module boundaries",
    "Primary runtime flows",
    "API and security boundaries",
    "Data ownership and migrations",
    "Caching and consistency",
    "External integrations",
    "Observability and operations",
)
sections = {}
current = None
tick = chr(96)
for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    if line.startswith("## "):
        current = line[3:]
        sections.setdefault(current, [])
    elif current is not None:
        sections[current].append(line)

for section in required:
    matches = [
        match.group(1)
        for line in sections.get(section, [])
        if (match := re.fullmatch(r"- Evidence: " + tick + r"([^" + tick + r"]+)" + tick, line))
    ]
    if len(matches) != 1:
        raise SystemExit(
            f"section '{section}' requires exactly one section Evidence path line"
        )
    print(f"{section}\t{matches[0]}")
PY
)" || fail "engineering overview has incomplete section-specific evidence"

  section_evidence_paths=()
  while IFS=$'\t' read -r evidence_section evidence_path; do
    [ -n "${evidence_section}" ] && [ -n "${evidence_path}" ] \
      || fail "engineering overview emitted an invalid section-evidence record"
    case "${evidence_path}" in
      /*|../*|*/../*|*/..)
        fail "section evidence path must stay inside the repository: ${evidence_path}"
        ;;
    esac
    [ -f "${ROOT}/${evidence_path}" ] \
      || fail "section evidence path does not exist for ${evidence_section}: ${evidence_path}"
    require_repository_owned_evidence "section" "${evidence_path}"
    section_evidence_paths+=("${evidence_path}")
  done <<< "${section_evidence}"

  distinct_section_evidence="$(printf '%s\n' "${section_evidence_paths[@]}" \
    | LC_ALL=C sort -u | awk 'END { print NR }')"
  [ "${distinct_section_evidence}" -ge 6 ] \
    || fail "engineering overview requires at least six distinct section-evidence paths"

  # Stable modules in the actual reactor must be represented. Keep the
  # handoff-only telemetry exception above separate from this mechanical check.
  if [ -f "${ROOT}/backend/pom.xml" ]; then
    active_modules="$(python3 - "${ROOT}/backend/pom.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
namespace = root.tag.partition("}")[0] + "}" if root.tag.startswith("{") else ""
modules = root.find(f"{namespace}modules")
names = [] if modules is None else [
    (element.text or "").strip()
    for element in modules.findall(f"{namespace}module")
]
if any(not name for name in names):
    raise SystemExit("backend/pom.xml contains an empty top-level module")
if len(names) != len(set(names)):
    raise SystemExit("backend/pom.xml contains duplicate top-level modules")
print("\n".join(names))
PY
)" || fail "cannot parse active top-level modules from backend/pom.xml"
    while IFS= read -r module; do
      [ -n "${module}" ] || continue
      [ "${module}" = "event-logging-to-db-feature" ] && continue
      grep -Fq "\`backend/${module}\`" "${DOC}" \
        || fail "docs/architecture-overview.md does not document active backend module: backend/${module}"
    done <<< "${active_modules}"
  fi

else
  if grep -Fq "ARCHITECTURE-TODO:" "${DOC}"; then
    echo "check-architecture-overview: MVP draft contains unresolved markers; finalize them before engineering handoff"
  fi
fi

echo "check-architecture-overview: passed (${phase})"
