#!/usr/bin/env python3
"""Ensure controllable OpenAPI inputs have a constraint or an explicit reason.

The parser is intentionally dependency-free because generated projects must run
the gate before any Python package is installed. It validates the conventional
YAML shape used by the template: operation parameters plus component DTO
properties reached by request bodies are covered by the same property rule.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


spec = Path(sys.argv[1] if len(sys.argv) > 1 else "backend/application/src/main/resources/api/v1/specs/openapi.yaml")
if not spec.is_file():
    print(f"check-openapi-input-constraints: missing OpenAPI spec: {spec}", file=sys.stderr)
    raise SystemExit(1)

lines = spec.read_text(encoding="utf-8").splitlines()
constraints = {
    "minLength", "maxLength", "pattern", "format", "minimum", "maximum",
    "exclusiveMinimum", "exclusiveMaximum", "multipleOf", "minItems", "maxItems",
    "uniqueItems", "minProperties", "maxProperties", "enum", "const",
}
violations: list[str] = []


def indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def block(start: int, base: int) -> list[tuple[int, str]]:
    result: list[tuple[int, str]] = []
    for pos in range(start + 1, len(lines)):
        current = lines[pos]
        if current.strip() and indent(current) <= base:
            break
        result.append((pos, current))
    return result


# Named component schemas are common for enums and reusable constrained scalar
# types. A `$ref` to one is itself an explicit constraint when that target has
# `enum`, `pattern`, bounds, or another accepted constraint.
schema_blocks: dict[str, list[tuple[int, str]]] = {}
schemas_line = next((i for i, line in enumerate(lines) if re.match(r"^\s{2}schemas:\s*$", line)), None)
if schemas_line is not None:
    for index in range(schemas_line + 1, len(lines)):
        line = lines[index]
        if line.strip() and indent(line) <= 2:
            break
        match = re.match(r"^\s{4}([A-Za-z0-9_.-]+):\s*$", line)
        if match:
            schema_blocks[match.group(1)] = block(index, indent(line))


def keys(items: list[tuple[int, str]]) -> set[str]:
    found: set[str] = set()
    for _, item in items:
        match = re.match(r"^\s*([A-Za-z][A-Za-z0-9_-]*):", item)
        if match:
            found.add(match.group(1))
        for key in constraints | {"x-unconstrained-reason"}:
            if re.search(rf"\b{re.escape(key)}\s*:", item):
                found.add(key)
    return found


schema_ref = re.compile(r"\$ref:\s*[\"']?#/components/schemas/([A-Za-z0-9_.-]+)")


def keys_with_schema_refs(items: list[tuple[int, str]], visited: set[str] | None = None) -> set[str]:
    found = keys(items)
    visited = visited or set()
    for _, item in items:
        for schema_name in schema_ref.findall(item):
            if schema_name in visited:
                continue
            visited.add(schema_name)
            found |= keys_with_schema_refs(schema_blocks.get(schema_name, []), visited)
    return found


def validate_subject(line_no: int, label: str, subject: list[tuple[int, str]]) -> None:
    found = keys_with_schema_refs(subject)
    if constraints & found:
        return
    reason = next((line.strip() for _, line in subject if re.search(r"\bx-unconstrained-reason\s*:\s*\S+", line)), "")
    if reason:
        return
    violations.append(
        f"{spec}:{line_no}: {label} needs an explicit OpenAPI constraint or x-unconstrained-reason"
    )


# Parameters are direct controllable inputs. Every one needs a constraint or a
# documented reason. Header auth parameters are normally declared as security
# schemes and do not enter this loop.
for index, line in enumerate(lines):
    stripped = line.strip()
    if not re.match(r"^-\s+name:\s*", stripped):
        continue
    parent = block(index, indent(line))
    parent_keys = keys(parent)
    if "in" not in parent_keys:
        continue
    name = stripped.split(":", 1)[1].strip() or "parameter"
    validate_subject(index + 1, f"parameter '{name}'", [(index, line), *parent])

# Validate every property of an object request schema that is named in a
# requestBody. This avoids requiring output-only response DTO fields to invent
# meaningless constraints.
request_refs: set[str] = set()
in_request_body = False
request_indent = 0
for index, line in enumerate(lines):
    if re.match(r"^\s*requestBody:\s*$", line):
        in_request_body = True
        request_indent = indent(line)
        continue
    if in_request_body and line.strip() and indent(line) <= request_indent:
        in_request_body = False
    if in_request_body:
        match = re.search(r"\$ref:\s*[\"']?#/components/schemas/([A-Za-z0-9_.-]+)", line)
        if match:
            request_refs.add(match.group(1))

in_schemas = False
schema_name = ""
for index, line in enumerate(lines):
    if re.match(r"^\s{2}schemas:\s*$", line):
        in_schemas = True
        continue
    if in_schemas and line.strip() and indent(line) <= 2:
        in_schemas = False
        schema_name = ""
    if not in_schemas:
        continue
    schema_match = re.match(r"^\s{4}([A-Za-z0-9_.-]+):\s*$", line)
    if schema_match:
        schema_name = schema_match.group(1)
        continue
    if schema_name not in request_refs:
        continue
    if not re.match(r"^\s{6}properties:\s*$", line):
        continue
    properties_indent = indent(line)
    for property_index, property_line in block(index, properties_indent):
        if indent(property_line) != properties_indent + 2:
            continue
        property_match = re.match(r"^\s{8}([A-Za-z0-9_.-]+):", property_line)
        if not property_match:
            continue
        property_name = property_match.group(1)
        property_items = [(property_index, property_line), *block(property_index, indent(property_line))]
        validate_subject(property_index + 1, f"request property '{schema_name}.{property_name}'", property_items)

if violations:
    print(f"check-openapi-input-constraints: FAIL — {len(violations)} violation(s):", file=sys.stderr)
    print("\n".join(f"  {violation}" for violation in violations), file=sys.stderr)
    raise SystemExit(1)
print("check-openapi-input-constraints: passed")
