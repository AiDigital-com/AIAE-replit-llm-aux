#!/usr/bin/env python3
"""Reject undocumented service contracts and oversized ServiceImpl classes."""

from __future__ import annotations

import re
import sys
from pathlib import Path

MAX_IMPL_LINES = 260
MAX_PUBLIC_METHODS = 10
MAX_PRIVATE_METHODS = 8
MAX_INJECTED_FIELDS = 8
MAX_PUBLIC_METHOD_LINES = 60
MAX_PRIVATE_METHOD_LINES = 35

METHOD_START = re.compile(
    r"^\s*(?:(public|private|protected)\s+)?"
    r"(?!class\b|interface\b|enum\b|record\b)"
    r"(?:[\w.<>,?\[\]]+\s+)+(\w+)\s*\(([^)]*)\)"
    r"\s*(?:throws\s+[\w.,\s]+)?\s*(?:[;{]|\{).*$"
)
FIELD = re.compile(r"^\s*private\s+final\s+[^=;]+;\s*$")


def java_files(root: Path) -> list[Path]:
    return sorted(root.rglob("*.java")) if root.is_dir() else []


def previous_javadoc(lines: list[str], index: int) -> tuple[int, int, list[str]] | None:
    cursor = index - 1
    while cursor >= 0 and (not lines[cursor].strip() or lines[cursor].strip().startswith("@")):
        cursor -= 1
    if cursor < 0 or lines[cursor].strip() != "*/":
        return None
    end = cursor
    cursor -= 1
    while cursor >= 0 and "/**" not in lines[cursor]:
        cursor -= 1
    if cursor < 0:
        return None
    return cursor, end, lines[cursor : end + 1]


def has_summary(block: list[str]) -> bool:
    for raw in block:
        text = raw.strip().lstrip("*").strip()
        if text and not text.startswith("/") and not text.startswith("@"):
            return True
    return False


def parse_params(params: str) -> list[str]:
    if not params.strip():
        return []
    names: list[str] = []
    depth = 0
    current: list[str] = []
    for char in params:
        if char == "<":
            depth += 1
        elif char == ">" and depth:
            depth -= 1
        if char == "," and depth == 0:
            part = "".join(current).strip()
            current = []
            if part:
                names.append(part.split()[-1].replace("...", ""))
            continue
        current.append(char)
    part = "".join(current).strip()
    if part:
        names.append(part.split()[-1].replace("...", ""))
    return [name for name in names if name]


def scan_contract(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    violations: list[str] = []
    for i, raw in enumerate(lines):
        if re.search(r"\binterface\s+\w+Service\b", raw):
            block = previous_javadoc(lines, i)
            if not block or not has_summary(block[2]):
                violations.append(f"{path}:{i + 1}: service interface needs JavaDoc summary")
        stripped = raw.strip()
        if not stripped.endswith(";") or "(" not in stripped or stripped.startswith("//"):
            continue
        match = METHOD_START.match(raw)
        if not match:
            continue
        method_name = match.group(2)
        if method_name in {"equals", "hashCode", "toString"}:
            continue
        block = previous_javadoc(lines, i)
        if not block or not has_summary(block[2]):
            violations.append(f"{path}:{i + 1}: service method {method_name} needs JavaDoc summary")
            continue
        doc = "\n".join(block[2])
        for param in parse_params(match.group(3)):
            if f"@param {param}" not in doc:
                violations.append(f"{path}:{i + 1}: JavaDoc for {method_name} missing @param {param}")
        return_type = stripped.split("(", 1)[0].split()[-2]
        if return_type != "void" and "@return" not in doc:
            violations.append(f"{path}:{i + 1}: JavaDoc for {method_name} missing @return")
    return violations


def method_lengths(lines: list[str]) -> list[tuple[int, str, str, int]]:
    result: list[tuple[int, str, str, int]] = []
    i = 0
    while i < len(lines):
        raw = lines[i]
        match = METHOD_START.match(raw)
        if not match or "{" not in raw:
            i += 1
            continue
        visibility = match.group(1) or "package"
        name = match.group(2)
        depth = raw.count("{") - raw.count("}")
        start = i
        i += 1
        while i < len(lines) and depth > 0:
            depth += lines[i].count("{") - lines[i].count("}")
            i += 1
        result.append((start + 1, visibility, name, max(1, i - start)))
    return result


def scan_impl(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    violations: list[str] = []
    line_count = len(lines)
    injected_fields = sum(1 for line in lines if FIELD.match(line))
    methods = method_lengths(lines)
    public_methods = [m for m in methods if m[1] == "public"]
    private_methods = [m for m in methods if m[1] == "private"]
    if line_count > MAX_IMPL_LINES:
        violations.append(f"{path}:1: ServiceImpl has {line_count} lines; max {MAX_IMPL_LINES}. Split workflows/helpers.")
    if len(public_methods) > MAX_PUBLIC_METHODS:
        violations.append(f"{path}:1: ServiceImpl has {len(public_methods)} public methods; max {MAX_PUBLIC_METHODS}.")
    if len(private_methods) > MAX_PRIVATE_METHODS:
        violations.append(f"{path}:1: ServiceImpl has {len(private_methods)} private methods; max {MAX_PRIVATE_METHODS}.")
    if injected_fields > MAX_INJECTED_FIELDS:
        violations.append(f"{path}:1: ServiceImpl has {injected_fields} injected fields; max {MAX_INJECTED_FIELDS}.")
    for start, visibility, name, length in methods:
        limit = MAX_PRIVATE_METHOD_LINES if visibility == "private" else MAX_PUBLIC_METHOD_LINES
        if visibility in {"public", "private"} and length > limit:
            violations.append(f"{path}:{start}: {visibility} method {name} has {length} lines; max {limit}.")
    return violations


def main() -> int:
    roots = [Path(arg) for arg in sys.argv[1:]] or [Path("backend/service/src/main/java")]
    violations: list[str] = []
    scanned = 0
    for root in roots:
        for path in java_files(root):
            normalized = str(path).replace("\\", "/")
            if "/services/impl/" in normalized and path.name.endswith("ServiceImpl.java"):
                scanned += 1
                violations.extend(scan_impl(path))
            elif "/services/" in normalized and "/impl/" not in normalized and path.name.endswith("Service.java"):
                scanned += 1
                violations.extend(scan_contract(path))
    if violations:
        print(f"check-service-contract-quality: FAIL — {len(violations)} violation(s):", file=sys.stderr)
        for violation in violations:
            print(f"  {violation}", file=sys.stderr)
        return 1
    print(f"check-service-contract-quality: passed ({scanned} service file(s) scanned)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
