#!/usr/bin/env python3
"""Require a negative 400 controller/MVC test for every constrained API input."""
from __future__ import annotations

import re
import sys
from pathlib import Path


root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
spec = root / "backend/application/src/main/resources/api/v1/specs/openapi.yaml"
tests_root = root / "backend/application/src/test/java"
if not spec.is_file() or not tests_root.is_dir():
    print("check-api-validation-tests: passed (no API test surface)")
    raise SystemExit(0)

lines = spec.read_text(encoding="utf-8").splitlines()
constraint_pattern = re.compile(
    r"\b(?:minLength|maxLength|pattern|format|minimum|maximum|exclusiveMinimum|exclusiveMaximum|multipleOf|minItems|maxItems|uniqueItems|minProperties|maxProperties|enum|const)\s*:"
)
def indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def block(start: int, base: int) -> str:
    result: list[str] = []
    for position in range(start + 1, len(lines)):
        current = lines[position]
        if current.strip() and indent(current) <= base:
            break
        result.append(current)
    return "\n".join(result)


def component_blocks(section: str) -> dict[str, str]:
    """Return named component YAML blocks without requiring PyYAML."""
    section_line = next((i for i, line in enumerate(lines) if re.match(rf"^\s{{2}}{re.escape(section)}:\s*$", line)), None)
    if section_line is None:
        return {}
    result: dict[str, str] = {}
    for index in range(section_line + 1, len(lines)):
        line = lines[index]
        if line.strip() and indent(line) <= 2:
            break
        match = re.match(r"^\s{4}([A-Za-z0-9_.-]+):\s*$", line)
        if match:
            result[match.group(1)] = block(index, indent(line))
    return result


component_sources = {"schemas": component_blocks("schemas"), "parameters": component_blocks("parameters")}
reference_pattern = re.compile(r"\$ref:\s*[\"']?#/components/(schemas|parameters)/([A-Za-z0-9_.-]+)")


def dereference(value: str, visited: set[tuple[str, str]] | None = None) -> str:
    visited = visited or set()
    expanded = value
    for section, name in reference_pattern.findall(value):
        marker = (section, name)
        if marker in visited:
            continue
        visited.add(marker)
        component = component_sources.get(section, {}).get(name, "")
        expanded += "\n" + dereference(component, visited)
    return expanded


operations_with_input = 0
operation_start: int | None = None
operation_indent = 0


def count_operation(operation: str) -> None:
    global operations_with_input
    expanded = dereference(operation)
    if ("parameters:" in expanded or "requestBody:" in expanded) and constraint_pattern.search(expanded):
        operations_with_input += 1

for index, line in enumerate(lines):
    match = re.match(r"^(\s*)(get|post|put|patch|delete|options|head):\s*$", line)
    if match:
        if operation_start is not None:
            count_operation("\n".join(lines[operation_start:index]))
        operation_start = index
        operation_indent = len(match.group(1))
        continue
    if operation_start is not None and line.strip() and len(line) - len(line.lstrip(" ")) <= operation_indent:
        count_operation("\n".join(lines[operation_start:index]))
        operation_start = None

if operation_start is not None:
    count_operation("\n".join(lines[operation_start:]))

bad_request_assertions = 0
for source in tests_root.rglob("*Test.java"):
    text = source.read_text(encoding="utf-8")
    bad_request_assertions += len(re.findall(r"status\(\)\.isBadRequest\(\)", text))

if bad_request_assertions < operations_with_input:
    print(
        "check-api-validation-tests: FAIL — "
        f"{operations_with_input} constrained operation(s), but only {bad_request_assertions} explicit isBadRequest() MVC assertion(s). "
        "Add one negative 400 test per constrained operation.",
        file=sys.stderr,
    )
    raise SystemExit(1)
print("check-api-validation-tests: passed")
