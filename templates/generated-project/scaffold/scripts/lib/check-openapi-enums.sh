#!/usr/bin/env bash
# check-openapi-enums.sh - rejects inline OpenAPI enums that generate inner Java enum types.

set -euo pipefail

spec_path="${1:-backend/application/src/main/resources/api/v1/specs/openapi.yaml}"
[ -f "${spec_path}" ] || { echo "check-openapi-enums: missing OpenAPI spec: ${spec_path}" >&2; exit 1; }

python3 - "${spec_path}" <<'PY'
from pathlib import Path
import re
import sys

spec = Path(sys.argv[1])
lines = spec.read_text().splitlines()

schema_name = None
schema_indent = None
schemas_indent = None
in_components_schemas = False
violations = []

versioned_schema = re.compile(r'^[A-Z][A-Za-z0-9]*V[0-9]+$')
schema_header = re.compile(r'^([A-Za-z][A-Za-z0-9_]*)\s*:\s*$')
enum_token = re.compile(r'(^|[\s{,])enum\s*:')

def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip(' '))

def add(line_no: int, message: str) -> None:
    violations.append(f"{spec}:{line_no}: {message}")

for idx, raw in enumerate(lines, start=1):
    stripped = raw.strip()
    if not stripped or stripped.startswith('#'):
        continue

    indent = indent_of(raw)

    if re.match(r'^components\s*:\s*$', raw):
        in_components_schemas = False
        schema_name = None
        schema_indent = None
        schemas_indent = None
        continue

    if re.match(r'^\s{2}schemas\s*:\s*$', raw):
        in_components_schemas = True
        schemas_indent = indent
        schema_name = None
        schema_indent = None
        continue

    if in_components_schemas:
        if schemas_indent is not None and indent <= schemas_indent and not stripped.startswith('-'):
            in_components_schemas = False
            schema_name = None
            schema_indent = None
        elif indent == (schemas_indent or 0) + 2:
            match = schema_header.match(stripped)
            if match:
                schema_name = match.group(1)
                schema_indent = indent

    if not enum_token.search(raw):
        continue

    allowed_standalone_schema_enum = (
        in_components_schemas
        and schema_name is not None
        and schema_indent is not None
        and indent == schema_indent + 2
        and stripped.startswith('enum:')
    )

    if allowed_standalone_schema_enum:
        if not versioned_schema.match(schema_name):
            add(idx, f"enum schema '{schema_name}' must be versioned, e.g. '{schema_name}V1'")
        continue

    add(idx, "inline enum is forbidden; create components.schemas.<Name>V1 and reference it with $ref")

if violations:
    print(f"check-openapi-enums: FAIL - {len(violations)} violation(s):", file=sys.stderr)
    for violation in violations:
        print(f"  {violation}", file=sys.stderr)
    sys.exit(1)

print("check-openapi-enums: passed")
PY
