#!/usr/bin/env bash
# Rejects OpenAPI operations, schemas, and fields without descriptions.
set -euo pipefail
spec_path="${1:-backend/application/src/main/resources/api/v1/specs/openapi.yaml}"
[ -f "${spec_path}" ] || { echo "check-openapi-documentation: missing OpenAPI spec: ${spec_path}" >&2; exit 1; }
python3 - "$spec_path" <<'INNERPY'
from __future__ import annotations
import re
import sys
from pathlib import Path

spec = Path(sys.argv[1])
lines = spec.read_text(encoding="utf-8").splitlines()
HTTP = {"get", "post", "put", "patch", "delete", "options", "head"}
violations: list[str] = []

def indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))

def block(start: int, base: int) -> list[tuple[int, str]]:
    out = []
    for i in range(start + 1, len(lines)):
        if lines[i].strip() and indent(lines[i]) <= base:
            break
        out.append((i, lines[i]))
    return out

def has_key(items: list[tuple[int, str]], key: str) -> bool:
    pat = re.compile(rf"^\s*{re.escape(key)}:\s*\S+")
    return any(pat.match(line) for _, line in items)

def has_desc(items: list[tuple[int, str]]) -> bool:
    return has_key(items, "description")

for i, line in enumerate(lines):
    stripped = line.strip()
    if not stripped.endswith(":") or stripped[:-1] not in HTTP or indent(line) != 4:
        continue
    op = stripped[:-1].upper()
    items = block(i, indent(line))
    if not has_key(items, "operationId"):
        violations.append(f"{spec}:{i + 1}: {op} operation missing operationId")
    if not has_key(items, "summary"):
        violations.append(f"{spec}:{i + 1}: {op} operation missing summary")
    if not has_desc(items):
        violations.append(f"{spec}:{i + 1}: {op} operation missing description")
    for j, child in items:
        if re.match(r"^\s*-\s+name:\s*", child):
            param_items = block(j, indent(child))
            inline_has_desc = "description:" in child
            if not inline_has_desc and not has_desc(param_items):
                violations.append(f"{spec}:{j + 1}: parameter missing description")
        if re.match(r"^\s*requestBody:\s*$", child):
            if not has_desc(block(j, indent(child))):
                violations.append(f"{spec}:{j + 1}: requestBody missing description")

in_schemas = False
current_schema = ""
current_schema_indent = 0
for i, line in enumerate(lines):
    if line.startswith("  schemas:"):
        in_schemas = True
        continue
    if in_schemas and re.match(r"^  [A-Za-z][^:]*:", line):
        in_schemas = False
    if not in_schemas:
        continue
    m = re.match(r"^    ([A-Za-z0-9_.-]+):\s*$", line)
    if m:
        current_schema = m.group(1)
        current_schema_indent = indent(line)
        if not has_desc(block(i, current_schema_indent)):
            violations.append(f"{spec}:{i + 1}: schema {current_schema} missing description")
        continue
    if current_schema and re.match(r"^      properties:\s*$", line):
        props_indent = indent(line)
        for j, prop_line in block(i, props_indent):
            if indent(prop_line) != props_indent + 2:
                continue
            pm = re.match(r"^\s{8}([A-Za-z0-9_.-]+):", prop_line)
            if not pm or pm.group(1) in {"type", "items", "additionalProperties"}:
                continue
            if "description:" in prop_line:
                continue
            if not has_desc(block(j, indent(prop_line))):
                violations.append(f"{spec}:{j + 1}: schema {current_schema}.{pm.group(1)} missing description")

if violations:
    print(f"check-openapi-documentation: FAIL — {len(violations)} violation(s):", file=sys.stderr)
    for violation in violations:
        print(f"  {violation}", file=sys.stderr)
    sys.exit(1)
print("check-openapi-documentation: passed")
INNERPY
