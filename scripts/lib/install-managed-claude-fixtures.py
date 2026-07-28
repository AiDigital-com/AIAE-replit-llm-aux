#!/usr/bin/env python3
"""Install a staged Claude fixture tree without overwriting unowned content."""
from __future__ import annotations

import hashlib
import os
import re
import shutil
import sys
from pathlib import Path, PurePosixPath


if len(sys.argv) != 4:
    raise SystemExit(
        "usage: install-managed-claude-fixtures.py <stage> <target> <manifest>"
    )

stage = Path(sys.argv[1]).resolve()
target = Path(sys.argv[2]).resolve()
manifest_input = Path(sys.argv[3])
hash_pattern = re.compile(r"^[0-9a-f]{64}$")
managed_root_files = {
    "AI-DEVELOPMENT-GUIDE.md",
    "CLAUDE.md",
    "GDS-WORKFLOW-README.md",
    "agent-payload.skills",
}
managed_prefixes = (
    ".claude/agent_docs/",
    ".claude/rules/",
    ".claude/skills/",
)
managed_exact_claude_files = {".claude/tasks/README.md"}


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def safe_relative(raw: str) -> str:
    candidate = PurePosixPath(raw)
    if candidate.is_absolute() or not candidate.parts:
        raise ValueError(f"unsafe absolute/empty managed path: {raw!r}")
    if any(part in ("", ".", "..") for part in candidate.parts):
        raise ValueError(f"unsafe managed path traversal: {raw!r}")
    return candidate.as_posix()


def require_owned_namespace(relative: str) -> str:
    if (
        relative in managed_root_files
        or relative in managed_exact_claude_files
        or any(relative.startswith(prefix) for prefix in managed_prefixes)
    ):
        return relative
    raise ValueError(f"path is outside fixture-owned namespaces: {relative!r}")


def target_path(relative: str) -> Path:
    unresolved = target / relative
    current = target
    for part in PurePosixPath(relative).parts:
        current = current / part
        if current.is_symlink():
            raise ValueError(
                f"managed path contains a symlinked component: {relative!r}"
            )
    destination = unresolved.resolve(strict=False)
    try:
        destination.relative_to(target)
    except ValueError as error:
        raise ValueError(f"managed path escapes target: {relative!r}") from error
    return destination


if not stage.is_dir() or not target.is_dir():
    raise SystemExit("install-managed-claude-fixtures: stage and target must exist")

expected_manifest = target / ".claude" / ".aiae-fixtures-manifest"
provided_unresolved = Path(
    os.path.abspath(os.path.expanduser(str(manifest_input)))
)
provided_manifest = (
    provided_unresolved.parent.resolve(strict=False) / provided_unresolved.name
)
if provided_manifest != expected_manifest:
    raise SystemExit(
        "install-managed-claude-fixtures: manifest must be exactly "
        f"{expected_manifest}"
    )
try:
    manifest = target_path(".claude/.aiae-fixtures-manifest")
except ValueError as error:
    raise SystemExit(f"install-managed-claude-fixtures: unsafe manifest: {error}") from error

previous: dict[str, str] = {}
if manifest.is_file():
    for line_number, line in enumerate(
        manifest.read_text(encoding="utf-8").splitlines(), start=1
    ):
        if not line or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != 2:
            raise SystemExit(
                f"{manifest}:{line_number}: expected path<TAB>sha256"
            )
        try:
            relative = require_owned_namespace(safe_relative(fields[0]))
        except ValueError as error:
            raise SystemExit(f"{manifest}:{line_number}: {error}") from error
        if relative in previous:
            raise SystemExit(f"{manifest}:{line_number}: duplicate path {relative}")
        if not hash_pattern.fullmatch(fields[1]):
            raise SystemExit(f"{manifest}:{line_number}: invalid SHA-256")
        previous[relative] = fields[1]

desired: dict[str, tuple[Path, str]] = {}
for source in sorted(stage.rglob("*")):
    if source.is_symlink():
        raise SystemExit(f"staged fixture must not be a symlink: {source}")
    if not source.is_file():
        continue
    relative = require_owned_namespace(
        safe_relative(source.relative_to(stage).as_posix())
    )
    desired[relative] = (source, digest(source))

# Refuse edits to files already owned by an earlier install.
for relative, expected_hash in previous.items():
    destination = target_path(relative)
    if destination.exists():
        if not destination.is_file() or destination.is_symlink():
            raise SystemExit(f"managed fixture changed type: {relative}")
        if digest(destination) != expected_hash:
            raise SystemExit(
                f"managed fixture was edited locally; refusing overwrite: {relative}"
            )

# A same-name skill directory is a semantic collision even when none of its
# files happen to share a path with the staged skill.
skills_root = stage / ".claude" / "skills"
if skills_root.is_dir():
    for skill_source in sorted(skills_root.iterdir()):
        if not skill_source.is_dir():
            continue
        prefix = f".claude/skills/{skill_source.name}/"
        destination = target_path(prefix.rstrip("/"))
        owned = {path for path in previous if path.startswith(prefix)}
        if destination.exists() and not owned:
            raise SystemExit(
                f"skill collision outside fixture ownership: {prefix.rstrip('/')}"
            )
        if destination.is_dir() and owned:
            unowned = {
                path.relative_to(target).as_posix()
                for path in destination.rglob("*")
                if path.is_file()
                and path.relative_to(target).as_posix() not in previous
            }
            if unowned:
                first = sorted(unowned)[0]
                raise SystemExit(
                    f"unowned file inside managed skill directory: {first}"
                )

# Refuse unrelated files at paths the fixture needs to own. Identical files may
# be adopted on the first install; differing content requires an explicit human
# decision rather than silent replacement.
for relative, (_, expected_hash) in desired.items():
    destination = target_path(relative)
    if relative not in previous and destination.exists():
        if (
            not destination.is_file()
            or destination.is_symlink()
            or digest(destination) != expected_hash
        ):
            raise SystemExit(f"fixture path collision: {relative}")

# Delete only obsolete files recorded in the prior ownership manifest.
for relative in sorted(set(previous) - set(desired), reverse=True):
    destination = target_path(relative)
    if destination.exists():
        destination.unlink()

# Atomically replace each desired file.
for relative, (source, _) in desired.items():
    destination = target_path(relative)
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(f".{destination.name}.aiae-install-{os.getpid()}")
    shutil.copy2(source, temporary)
    os.replace(temporary, destination)

manifest.parent.mkdir(parents=True, exist_ok=True)
manifest_tmp = manifest.with_name(f".{manifest.name}.tmp-{os.getpid()}")
with manifest_tmp.open("w", encoding="utf-8") as output:
    output.write("# Managed by scripts/install-claude-fixtures.sh. Do not edit.\n")
    output.write("# path<TAB>sha256\n")
    for relative in sorted(desired):
        output.write(f"{relative}\t{desired[relative][1]}\n")
os.replace(manifest_tmp, manifest)

print(
    "install-managed-claude-fixtures: "
    f"installed {len(desired)} file(s), removed {len(set(previous) - set(desired))}"
)
