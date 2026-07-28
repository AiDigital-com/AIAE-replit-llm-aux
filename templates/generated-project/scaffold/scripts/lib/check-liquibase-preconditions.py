#!/usr/bin/env python3
"""Reject Liquibase changeSets that do not declare preConditions."""

from pathlib import Path
import sys
import xml.etree.ElementTree as ET


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def has_direct_preconditions(change_set: ET.Element) -> bool:
    return any(local_name(child.tag) == "preConditions" for child in list(change_set))


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "backend/migrations/src/main/resources/db/changelog")
    if not root.exists():
        print(f"check-liquibase-preconditions: skipped, missing {root}")
        return 0

    violations: list[str] = []
    for path in sorted(root.rglob("*.xml")):
        try:
            tree = ET.parse(path)
        except ET.ParseError as exc:
            violations.append(f"{path}: invalid XML: {exc}")
            continue

        for change_set in tree.iter():
            if local_name(change_set.tag) == "changeSet" and not has_direct_preconditions(change_set):
                change_id = change_set.attrib.get("id", "<missing-id>")
                author = change_set.attrib.get("author", "<missing-author>")
                violations.append(
                    f"{path}: changeSet id={change_id} author={author} must declare direct <preConditions>"
                )

    if violations:
        print("check-liquibase-preconditions: FAIL", file=sys.stderr)
        for violation in violations:
            print(f"  {violation}", file=sys.stderr)
        return 1

    print("check-liquibase-preconditions: passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
