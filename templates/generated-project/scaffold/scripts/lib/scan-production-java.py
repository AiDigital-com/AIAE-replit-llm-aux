#!/usr/bin/env python3
"""Production Java scanners for generated-project backend rules."""

from __future__ import annotations

import re
import sys
from pathlib import Path

SKIP_SUFFIXES = (
    "/api/v1/model/",
    "/api/v1/invoker/",
)
SKIP_FILES = {
    "AuthConstants.java",
}

CONST_DECL = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s*)*"
    r"(?:(?:public|protected|private)\s+)?"
    r"(?:static\s+)?(?:final\s+)?"
    r"[\w.<>,\s\[\]?]+\s+\w+\s*="
)
STATIC_FINAL = re.compile(r"^\s*(?:(?:public|protected|private)\s+)?static\s+final\b")
METHOD_SIG = re.compile(
    r"^\s*(?:(?:public|protected|private)\s+)?"
    r"(?:static\s+)?"
    r"(?!class\b|interface\b|enum\b|record\b)"
    r"[\w.<>,\s\[\]?]+\s+(\w+)\s*\([^;]*\)\s*(?:throws\s+[\w.,\s]+)?\s*\{?\s*$"
)
STATIC_METHOD = re.compile(
    r"^\s*(?:(?:public|protected|private)\s+)?"
    r"static\s+(?!final\b)(?!class\b|interface\b|enum\b|record\b)"
    r"[^=;{]+?\([^)]*\)"
)
TIME_NOW = re.compile(
    r"\b(?:Instant|LocalDate|LocalDateTime|LocalTime|OffsetDateTime|ZonedDateTime)\.now\s*\("
)
ENTITY_ALLOCATION = re.compile(
    r"\b(?:[A-Za-z0-9_]*Entity|var)\s+(\w+)\s*=\s*new\s+[A-Za-z0-9_]*Entity\s*\("
)
SETTER_CHAIN_LIMIT = 2

MAGIC_RULES = [
    ("jwt-claim-name", re.compile(r'"(?:user_id|full_name|azp)"')),
    ("cors-max-age", re.compile(r"maxAge\s*\(\s*\d{3,}\s*\)")),
    (
        "hardcoded-actuator-path",
        re.compile(
            r'"/actuator/health"|"/actuator/prometheus"|"/swagger-ui|"/v3/api-docs|"/api-docs'
        ),
    ),
    (
        "usage-logging-pool-magic",
        re.compile(
            r"new\s+LinkedBlockingQueue\s*\(\s*\d+\s*\)"
            r"|corePoolSize\s*=\s*\d+"
            r"|maximumPoolSize\s*=\s*\d+"
        ),
    ),
]


def should_skip_file(path: Path) -> bool:
    text = str(path).replace("\\", "/")
    if path.name in SKIP_FILES:
        return True
    if path.name.endswith("Api.java"):
        return True
    return any(part in text for part in SKIP_SUFFIXES)


def strip_comments_and_strings(line: str) -> str:
    """Remove // comments and string literals for safer matching."""
    if "//" in line:
        line = line.split("//", 1)[0]
    return re.sub(r'"(?:\\.|[^"\\])*"', '""', line)


def in_method_body(lines: list[str], index: int) -> bool:
    depth = 0
    body_threshold: int | None = None
    pending_method = False
    for raw in lines[: index + 1]:
        if CONST_DECL.match(raw) or STATIC_FINAL.match(raw):
            depth += raw.count("{") - raw.count("}")
            pending_method = False
            continue
        if METHOD_SIG.match(raw):
            if "{" in raw:
                body_threshold = depth + raw.count("{")
                pending_method = False
            else:
                pending_method = True
        elif pending_method and "{" in raw:
            body_threshold = depth + raw.count("{")
            pending_method = False
        depth += raw.count("{") - raw.count("}")
    if body_threshold is None:
        return False
    return depth >= body_threshold


def scan_magic(path: Path) -> list[str]:
    violations: list[str] = []
    lines = path.read_text(encoding="utf-8").splitlines()
    for i, raw in enumerate(lines):
        stripped = raw.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
            continue
        if stripped.startswith("@"):
            continue
        if CONST_DECL.match(raw) or STATIC_FINAL.match(raw):
            continue
        if not in_method_body(lines, i):
            continue
        for name, pattern in MAGIC_RULES:
            if pattern.search(raw):
                violations.append(f"[{name}] {path}:{i + 1}: {raw.strip()[:120]}")
                break
    return violations


def scan_static(path: Path) -> list[str]:
    violations: list[str] = []
    for i, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        stripped = raw.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
            continue
        if "@Bean" in raw:
            continue
        if STATIC_FINAL.match(raw):
            continue
        if re.search(r"static\s+final\s+(?:Logger|org\.slf4j\.Logger)\b", raw):
            continue
        if re.search(r"static\s+(?:class|interface|enum|record)\b", raw):
            continue
        if re.match(r"^\s*static\s*\{", raw):
            continue
        if not STATIC_METHOD.search(raw):
            continue
        if "void main(" in raw:
            continue
        violations.append(f"{path}:{i}: {stripped[:120]}")
    return violations


def scan_time(path: Path) -> list[str]:
    violations: list[str] = []
    if path.name == "CurrentTimeImpl.java":
        return violations
    for i, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        stripped = raw.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
            continue
        line = strip_comments_and_strings(raw)
        if TIME_NOW.search(line):
            violations.append(f"{path}:{i}: use injected CurrentTime instead of direct now(): {stripped[:120]}")
    return violations


def scan_manual_mapping(path: Path) -> list[str]:
    violations: list[str] = []
    lines = path.read_text(encoding="utf-8").splitlines()
    for i, raw in enumerate(lines):
        line = strip_comments_and_strings(raw)
        match = ENTITY_ALLOCATION.search(line)
        if not match:
            continue
        variable = match.group(1)
        setter_lines: list[int] = []
        setter = re.compile(rf"\b{re.escape(variable)}\.set[A-Z]\w*\s*\(")
        for j in range(i + 1, min(i + 80, len(lines))):
            candidate = strip_comments_and_strings(lines[j])
            if METHOD_SIG.match(candidate):
                break
            if setter.search(candidate):
                setter_lines.append(j + 1)
            if len(setter_lines) >= SETTER_CHAIN_LIMIT:
                joined = ", ".join(str(line_no) for line_no in setter_lines[:SETTER_CHAIN_LIMIT])
                violations.append(
                    f"{path}:{i + 1}: manual entity mapping for '{variable}' "
                    f"(setter chain at lines {joined}); use MapStruct mapper.toEntity/updateEntity"
                )
                break
    return violations


def collect_dirs(args: list[str]) -> list[Path]:
    if args:
        return [Path(p) for p in args]
    roots = []
    for part in Path("backend").glob("*/src/main/java"):
        if part.is_dir():
            roots.append(part)
    return roots


def main() -> int:
    if len(sys.argv) < 2 or sys.argv[1] not in {"magic", "static", "time", "mapping"}:
        print("Usage: scan-production-java.py <magic|static|time|mapping> [src_root...]", file=sys.stderr)
        return 2

    mode = sys.argv[1]
    dirs = collect_dirs(sys.argv[2:])
    if not dirs:
        print(f"scan-production-java ({mode}): no source directories", file=sys.stderr)
        return 0

    violations: list[str] = []
    for root in dirs:
        if not root.is_dir():
            continue
        for path in sorted(root.rglob("*.java")):
            if should_skip_file(path):
                continue
            if mode == "magic":
                violations.extend(scan_magic(path))
            elif mode == "static":
                violations.extend(scan_static(path))
            elif mode == "time":
                violations.extend(scan_time(path))
            else:
                violations.extend(scan_manual_mapping(path))

    labels = {
        "magic": "check-production-magic-values",
        "static": "check-production-static-methods",
        "time": "check-production-current-time",
        "mapping": "check-production-manual-mapping",
    }
    label = labels[mode]
    if violations:
        print(f"{label}: FAIL — {len(violations)} violation(s):", file=sys.stderr)
        for v in violations:
            print(f"  {v}", file=sys.stderr)
        return 1

    print(f"{label}: OK ({len(dirs)} source tree(s) scanned)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
