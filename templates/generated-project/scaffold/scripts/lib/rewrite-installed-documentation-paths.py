#!/usr/bin/env python3
"""Rewrite template-control-plane paths in content copied into a project."""
from __future__ import annotations

import sys
from pathlib import Path


content_root = Path(sys.argv[1] if len(sys.argv) > 1 else ".claude/agent_docs")
if not content_root.is_dir():
    print(
        f"rewrite-installed-documentation-paths: missing content root: {content_root}",
        file=sys.stderr,
    )
    raise SystemExit(1)

replacements = (
    ("custom_instruction/instructions.md", "CLAUDE.md"),
    (
        "Copy from `templates/generated-project/scaffold/`",
        "Work from the installed project root",
    ),
    ("templates/generated-project/scaffold/", ""),
    ("templates/generated-project/", ".claude/agent_docs/"),
)

for document in sorted(content_root.rglob("*.md")):
    original = document.read_text(encoding="utf-8")
    rewritten = original
    for source, target in replacements:
        rewritten = rewritten.replace(source, target)
    if rewritten != original:
        document.write_text(rewritten, encoding="utf-8")

print(f"rewrite-installed-documentation-paths: passed ({content_root})")
