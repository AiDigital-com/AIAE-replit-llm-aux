#!/usr/bin/env python3
"""Find active Liquibase changelogs that depend on a removable database object."""

from __future__ import annotations

import re
from pathlib import Path


_XML_COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)
_SQL_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)
_SQL_LINE_COMMENT = re.compile(r"--[^\n]*")
_FORMATTED_SQL_HEADER = re.compile(
    r"^[ \t]*--liquibase[ \t]+formatted[ \t]+sql\b",
    re.IGNORECASE | re.MULTILINE,
)
_FORMATTED_SQL_ORDINARY_COMMENT = re.compile(r"--(?=[ \t]|$)[^\n]*")
_INCLUDE_TAG = re.compile(r"<include\b[^>]*>", re.IGNORECASE)
_INCLUDE_ALL_TAG = re.compile(r"<includeAll\b[^>]*>", re.IGNORECASE)
_SQL_FILE_TAG = re.compile(r"<sqlFile\b[^>]*>", re.IGNORECASE)


def _without_comments(text: str, suffix: str) -> str:
    def blank(match: re.Match[str]) -> str:
        return "".join("\n" if char == "\n" else " " for char in match.group())

    if suffix.lower() == ".xml":
        return _XML_COMMENT.sub(blank, text)
    if suffix.lower() != ".sql":
        return text

    without_blocks = _SQL_BLOCK_COMMENT.sub(blank, text)
    # In formatted SQL, `--rollback`, `--precondition-*`, `--property`, and
    # similar no-space directives are executable Liquibase metadata. Preserve
    # every such directive fail-closed; strip only ordinary `-- comment` text.
    line_pattern = (
        _FORMATTED_SQL_ORDINARY_COMMENT
        if _FORMATTED_SQL_HEADER.search(without_blocks)
        else _SQL_LINE_COMMENT
    )
    return line_pattern.sub(
        lambda match: "".join("\n" if char == "\n" else " " for char in match.group()),
        without_blocks,
    )


def _attribute(tag: str, name: str) -> str | None:
    match = re.search(
        rf"\b{re.escape(name)}\s*=\s*([\"'])(.*?)\1",
        tag,
        flags=re.IGNORECASE | re.DOTALL,
    )
    return match.group(2) if match else None


def _resolve_reference(resources_root: Path, current: Path, tag: str, attribute: str) -> Path:
    reference = _attribute(tag, attribute)
    if not reference:
        raise RuntimeError(f"Liquibase tag is missing {attribute}: {tag.strip()}")
    relative = (_attribute(tag, "relativeToChangelogFile") or "").lower() == "true"
    candidate = (current.parent if relative else resources_root) / reference
    resolved = candidate.resolve()
    try:
        resolved.relative_to(resources_root.resolve())
    except ValueError as error:
        raise RuntimeError(
            f"Liquibase reference escapes migrations resources: {reference}"
        ) from error
    return resolved


def find_active_token_references(
    resources_root: Path,
    master: Path,
    master_text: str,
    excluded: set[Path],
    token: str,
) -> list[str]:
    """Return file:line evidence for active references outside excluded changelogs."""
    resources_root = resources_root.resolve()
    master = master.resolve()
    excluded = {path.resolve() for path in excluded}
    token_pattern = re.compile(
        rf"(?<![A-Za-z0-9_]){re.escape(token)}(?![A-Za-z0-9_])",
        re.IGNORECASE,
    )
    pending = [master]
    seen: set[Path] = set()
    findings: list[str] = []

    while pending:
        current = pending.pop()
        if current in seen or current in excluded:
            continue
        seen.add(current)
        if not current.is_file():
            raise RuntimeError(
                f"active Liquibase reference is missing: "
                f"{current.relative_to(resources_root)}"
            )

        text = master_text if current == master else current.read_text(encoding="utf-8")
        searchable = _without_comments(text, current.suffix)
        for match in token_pattern.finditer(searchable):
            line = searchable.count("\n", 0, match.start()) + 1
            findings.append(f"{current.relative_to(resources_root)}:{line}")

        if current.suffix.lower() != ".xml":
            continue

        for tag in _INCLUDE_TAG.findall(searchable):
            included = _resolve_reference(resources_root, current, tag, "file")
            if included.suffix.lower() != ".xml":
                raise RuntimeError(
                    "safe feature removal supports XML Liquibase changelog includes only; "
                    f"review manually: {included.relative_to(resources_root)}"
                )
            pending.append(included)
        for tag in _SQL_FILE_TAG.findall(searchable):
            pending.append(_resolve_reference(resources_root, current, tag, "path"))
        for tag in _INCLUDE_ALL_TAG.findall(searchable):
            directory = _resolve_reference(resources_root, current, tag, "path")
            if not directory.is_dir():
                raise RuntimeError(
                    f"active Liquibase includeAll directory is missing: "
                    f"{directory.relative_to(resources_root)}"
                )
            for path in sorted(directory.rglob("*")):
                if not path.is_file():
                    continue
                if path.suffix.lower() in {".yaml", ".yml", ".json"}:
                    raise RuntimeError(
                        "safe feature removal supports XML Liquibase changelogs only; "
                        f"review manually: {path.relative_to(resources_root)}"
                    )
                if path.suffix.lower() in {".xml", ".sql"}:
                    pending.append(path.resolve())

    return sorted(set(findings))
