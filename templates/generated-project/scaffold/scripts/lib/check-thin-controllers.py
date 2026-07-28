#!/usr/bin/env python3
"""Reject business logic from generated OpenAPI controllers.

`web/` is deliberately excluded: infrastructure controllers such as the SPA
fallback own routing and may need a small HTTP-specific conditional. API
controllers live only below `controllers/` and are delegation boundaries.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


root = Path(sys.argv[1] if len(sys.argv) > 1 else "backend/application/src/main/java")
if not root.is_dir():
    print("check-thin-controllers: passed (no application Java sources)")
    raise SystemExit(0)

violations: list[str] = []
# A naked `?` appears in Java wildcard generics (`ResponseEntity<?>`), so a
# ternary requires both delimiter tokens on the same code line.
branch_pattern = re.compile(r"\b(?:if|switch|for|while|do|try|catch)\b|\?[^;{}\n]+:")
repository_pattern = re.compile(r"\b[A-Za-z0-9_]*Repository\b")
dto_constructor_pattern = re.compile(r"\bnew\s+[A-Za-z_][A-Za-z0-9_]*V\d+\s*\(")
stream_pattern = re.compile(r"\.stream\s*\(")


def code_without_comments_and_literals(source: str) -> str:
    """Keep line positions while preventing JavaDoc/comments/text from matching."""
    source = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), source, flags=re.S)
    source = re.sub(r"//[^\n]*", "", source)
    source = re.sub(r'"(?:\\.|[^"\\])*"', '""', source)
    source = re.sub(r"'(?:\\.|[^'\\])*'", "''", source)
    return source


for controller in sorted(root.rglob("*Controller.java")):
    # Infrastructure MVC controllers intentionally stay outside controllers/.
    if "controllers" not in controller.parts:
        continue
    source = code_without_comments_and_literals(controller.read_text(encoding="utf-8"))
    for line_no, line in enumerate(source.splitlines(), start=1):
        if branch_pattern.search(line):
            violations.append(
                f"{controller}:{line_no}: API controllers may not branch, loop, use ternaries, or catch; delegate to a service"
            )
        if repository_pattern.search(line):
            violations.append(
                f"{controller}:{line_no}: API controllers may not reference repositories; delegate to a service"
            )
        if dto_constructor_pattern.search(line):
            violations.append(
                f"{controller}:{line_no}: API controllers may not construct generated *Vn DTOs; use a mapper"
            )
        if stream_pattern.search(line):
            violations.append(
                f"{controller}:{line_no}: API controllers may not transform collections with streams; delegate to a service or mapper"
            )

if violations:
    print(f"check-thin-controllers: FAIL — {len(violations)} violation(s):", file=sys.stderr)
    print("\n".join(f"  {violation}" for violation in violations), file=sys.stderr)
    raise SystemExit(1)

print("check-thin-controllers: passed")
