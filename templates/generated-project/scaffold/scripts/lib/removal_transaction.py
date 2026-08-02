#!/usr/bin/env python3
"""Apply scaffold feature removal atomically enough to roll back ordinary failures."""

from __future__ import annotations

import os
import shutil
import stat
import tempfile
from pathlib import Path


ARCHITECTURE_PATH = Path("docs/architecture-overview.md")


def _write_atomic(path: Path, content: str, mode: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, stat.S_IMODE(mode))
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def apply_removal_transaction(
    root: Path,
    changes: dict[Path, str],
    delete_paths: tuple[Path, ...],
) -> None:
    """Apply validated changes and restore the original tree on ordinary failure.

    The canonical architecture overview is deliberately written last: it records
    the completed state only after source, configuration, and owned paths changed.
    """

    root = root.resolve()
    architecture = root / ARCHITECTURE_PATH
    if architecture not in changes:
        raise RuntimeError("removal transaction must update docs/architecture-overview.md")

    originals: dict[Path, tuple[bytes, int]] = {}
    for path in changes:
        resolved = path.resolve()
        if not resolved.is_relative_to(root):
            raise RuntimeError(f"change path escapes project root: {path}")
        if not path.is_file():
            raise RuntimeError(f"changed file is missing: {path}")
        originals[path] = (path.read_bytes(), path.stat().st_mode)

    for path in delete_paths:
        resolved = path.resolve()
        if not resolved.is_relative_to(root):
            raise RuntimeError(f"delete path escapes project root: {path}")
        if not path.exists():
            raise RuntimeError(f"delete path is missing: {path}")

    stage = Path(tempfile.mkdtemp(prefix=".aiae-removal-transaction-", dir=root))
    moved: list[tuple[Path, Path]] = []
    ordered_changes = [path for path in changes if path != architecture] + [architecture]

    try:
        for path in ordered_changes[:-1]:
            _, mode = originals[path]
            _write_atomic(path, changes[path], mode)

        for index, path in enumerate(delete_paths):
            backup = stage / f"removed-{index}"
            backup.parent.mkdir(parents=True, exist_ok=True)
            os.replace(path, backup)
            moved.append((path, backup))

        if os.environ.get("AIAE_REMOVE_FAIL_BEFORE_ARCHITECTURE") == "1":
            raise RuntimeError("injected failure before architecture overview update")

        _, architecture_mode = originals[architecture]
        _write_atomic(architecture, changes[architecture], architecture_mode)
    except BaseException:
        for original_path, backup in reversed(moved):
            if original_path.exists():
                if original_path.is_dir():
                    shutil.rmtree(original_path)
                else:
                    original_path.unlink()
            original_path.parent.mkdir(parents=True, exist_ok=True)
            os.replace(backup, original_path)

        for path, (content, mode) in originals.items():
            _write_atomic(path, content.decode("utf-8"), mode)
        raise
    finally:
        shutil.rmtree(stage, ignore_errors=True)

