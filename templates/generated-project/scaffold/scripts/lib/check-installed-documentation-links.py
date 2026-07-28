#!/usr/bin/env python3
"""Verify project-local documentation references that survive materialization.

Portable skills commonly use backticked paths rather than Markdown links, so a
normal Markdown-link checker misses the most costly failure: a generated
project referring to a document that existed only in the template repository.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
scan_roots = [
    root / ".claude",
    root / ".agents",
    root / ".github",
    root / "backend",
    root / "frontend",
    root / "CLAUDE.md",
    root / "AGENTS.md",
    root / "replit.md",
    root / "AI-DEVELOPMENT-GUIDE.md",
]
excluded_parts = {".git", ".llm-aux-cache", "node_modules", "target", "dist", "build"}
text_suffixes = {
    ".java",
    ".js",
    ".mjs",
    ".cjs",
    ".md",
    ".txt",
    ".ts",
    ".tsx",
    ".xml",
    ".yml",
    ".yaml",
}
reference = re.compile(r"(?<![A-Za-z0-9_.-])(\.claude/(?:agent_docs|rules)/[A-Za-z0-9_./-]+(?:\.md|\.xml|\.yml|\.yaml)?)(?![A-Za-z0-9_/-])")
removed_control_plane_reference = re.compile(
    r"(?<![A-Za-z0-9_.-])"
    r"((?:templates/generated-project|custom_instruction)/"
    r"[A-Za-z0-9_./-]+\.(?:md|xml|yml|yaml))"
    r"(?![A-Za-z0-9_/-])"
)
markdown_link = re.compile(r"\]\(([^)]+)\)")
violations: list[str] = []


def files_under(item: Path) -> list[Path]:
    if item.is_file():
        return [item]
    if item.is_dir():
        return [
            path
            for path in item.rglob("*")
            if path.is_file()
            and not excluded_parts.intersection(path.relative_to(root).parts)
        ]
    return []


for scan_root in scan_roots:
    for source in files_under(scan_root):
        if source.suffix.lower() not in text_suffixes and source.name not in {
            "CLAUDE.md",
            "AI-DEVELOPMENT-GUIDE.md",
        }:
            continue
        try:
            text = source.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for line_no, line in enumerate(text.splitlines(), start=1):
            for match in removed_control_plane_reference.finditer(line):
                violations.append(
                    f"{source}:{line_no}: installed content references removed "
                    f"template control-plane path: {match.group(1)}"
                )
            for match in reference.finditer(line):
                target = root / match.group(1).rstrip(".,;:)]}`")
                if not target.exists():
                    violations.append(f"{source}:{line_no}: installed documentation reference does not exist: {match.group(1)}")
            if source.suffix.lower() != ".md":
                continue
            for match in markdown_link.finditer(line):
                target_text = match.group(1).strip().strip("<>")
                if not target_text or target_text.startswith(("#", "http://", "https://", "mailto:")):
                    continue
                target_text = target_text.split("#", 1)[0].split("?", 1)[0]
                if not target_text:
                    continue
                target = (source.parent / target_text).resolve()
                if root not in target.parents and target != root:
                    violations.append(f"{source}:{line_no}: documentation link escapes project root: {match.group(1)}")
                elif not target.exists():
                    violations.append(f"{source}:{line_no}: Markdown documentation link does not exist: {match.group(1)}")

if violations:
    print(f"check-installed-documentation-links: FAIL — {len(violations)} broken reference(s):", file=sys.stderr)
    print("\n".join(f"  {violation}" for violation in violations), file=sys.stderr)
    raise SystemExit(1)
print("check-installed-documentation-links: passed")
