#!/usr/bin/env python3
"""Remove MVP usage logging while refusing unsafe business-code rewrites."""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

from liquibase_dependency_guard import find_active_token_references


LOG_USAGE_IMPORT = re.compile(r"^[ \t]*import\s+[\w.]+\.usagelogging\.LogUsage;\s*\n", re.MULTILINE)
LOG_USAGE_ANNOTATION = re.compile(r"^[ \t]*@LogUsage\s*\([^\n]*\)\s*(?://[^\n]*)?\n", re.MULTILINE)
RESIDUAL_JAVA_USAGE = re.compile(
    r"\bUsageAttributes\b"
    r"|\bUsageEvent(?:Sink)?\b"
    r"|\bUsageLogger\b"
    r"|\.usagelogging\."
    r"|@LogUsage\b"
)


def read(path: Path) -> str:
    if not path.is_file():
        raise RuntimeError(f"required file is missing: {path}")
    return path.read_text(encoding="utf-8")


def replace_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE | re.DOTALL)
    if count != 1:
        raise RuntimeError(f"expected exactly one {label}; found {count}")
    return updated


def remove_internal_dependency(text: str) -> tuple[str, int]:
    pattern = (
        r"\n[ \t]*<dependency>\s*"
        r"<groupId>\$\{project\.groupId}</groupId>\s*"
        r"<artifactId>event-logging-to-db-feature</artifactId>"
        r".*?</dependency>"
    )
    return re.subn(pattern, "", text, flags=re.MULTILINE | re.DOTALL)


def remove_yaml_child(text: str, child: str, next_child: str | None = None) -> str:
    if next_child:
        pattern = rf"\n  {re.escape(child)}:\n.*?(?=\n  {re.escape(next_child)}:)"
    else:
        pattern = rf"\n  {re.escape(child)}:\n(?:    .*\n?)*"
    return replace_once(text, pattern, "", f"app.{child} configuration")


def prepare(root: Path) -> tuple[dict[Path, str], tuple[Path, ...]]:
    backend = root / "backend"
    module = backend / "event-logging-to-db-feature"
    if not module.is_dir():
        raise RuntimeError("event-logging-to-db-feature is already absent")

    changes: dict[Path, str] = {}

    parent = backend / "pom.xml"
    parent_text = read(parent)
    parent_text = replace_once(
        parent_text,
        r"\n[ \t]*<module>event-logging-to-db-feature</module>",
        "",
        "event-logging module declaration",
    )
    parent_text, dependency_count = remove_internal_dependency(parent_text)
    if dependency_count != 1:
        raise RuntimeError(
            "expected one managed event-logging dependency in backend/pom.xml; "
            f"found {dependency_count}"
        )
    parent_text = replace_once(
        parent_text,
        r"\n[ \t]*<!-- The service module deliberately keeps this edge.*?-->\s*"
        r"<ignoredUnusedDeclaredDependency>"
        r"\$\{project\.groupId}:event-logging-to-db-feature"
        r"</ignoredUnusedDeclaredDependency>",
        "",
        "event-logging dependency-analyzer exception",
    )
    parent_text = replace_once(
        parent_text,
        r"\n         `event-logging-to-db-feature` is the self-contained usage-logging Java\n"
        r"         feature \(annotation \+ aspect \+ entity \+ repo\); its Liquibase changelog\n"
        r"         remains centralized in migrations\. Drop both through the handoff\n"
        r"         command to fully remove the feature from future builds/schemas\.",
        "",
        "event-logging parent-module documentation",
    )
    changes[parent] = parent_text

    dependency_analysis = backend / "DEPENDENCY-ANALYSIS.md"
    dependency_analysis_text = read(dependency_analysis)
    dependency_analysis_text = replace_once(
        dependency_analysis_text,
        r"\nThe allowlist contains exactly two coordinates:\n\n"
        r"- `org\.projectlombok:lombok` — required at compile time for its annotation\n"
        r"  processor, while the compiled classes no longer reference the Lombok JAR\.\n"
        r"- `\$\{project\.groupId\}:event-logging-to-db-feature` —.*?"
        r"\nThe second allowance covers only that empty post-initialization lifecycle\n"
        r"window\. It is not a wildcard and does not suppress analysis of any other\n"
        r"internal or external dependency\.\n",
        "\nThe allowlist contains exactly one coordinate:\n\n"
        "- `org.projectlombok:lombok` — required at compile time for its annotation\n"
        "  processor, while the compiled classes no longer reference the Lombok JAR.\n",
        "event-logging dependency-analysis documentation",
    )
    changes[dependency_analysis] = dependency_analysis_text

    active_dependency_count = 0
    for pom in backend.rglob("pom.xml"):
        if pom == parent or pom.is_relative_to(module):
            continue
        updated, count = remove_internal_dependency(read(pom))
        if count:
            changes[pom] = updated
            active_dependency_count += count
    if active_dependency_count < 1:
        raise RuntimeError("no active module depends on event-logging-to-db-feature")

    service_pom = backend / "service/pom.xml"
    service_text = changes.get(service_pom, read(service_pom))
    service_text = replace_once(
        service_text,
        r"    <!-- Business orchestration\. Depends on domain; add external-services only\n"
        r".*?line from db\.changelog-master\.xml\. -->",
        "    <!-- Business orchestration. Depends on domain; add external-services only\n"
        "         when real external integrations exist. NEVER depend on application.\n"
        "         Hosts the AppException family under service/common/error/. -->",
        "event-logging service-module documentation",
    )
    changes[service_pom] = service_text

    java_changes: dict[Path, str] = {}
    blocked: list[str] = []
    bigquery_sink_dirs: set[Path] = set()
    for java in backend.rglob("*.java"):
        if java.is_relative_to(module):
            continue
        rel = java.relative_to(root).as_posix()
        if rel.endswith("/external/bigquery/usagelogging/BigQueryUsageEventSink.java"):
            bigquery_sink_dirs.add(java.parent)
            continue
        original = read(java)
        updated = LOG_USAGE_IMPORT.sub("", original)
        updated = LOG_USAGE_ANNOTATION.sub("", updated)
        if RESIDUAL_JAVA_USAGE.search(updated):
            blocked.append(rel)
        elif updated != original:
            java_changes[java] = updated
    if blocked:
        raise RuntimeError(
            "business code still has usage-logging types that require a semantic edit. "
            "Remove UsageAttributes/sink/logger dependencies first, then retry:\n  "
            + "\n  ".join(blocked)
        )
    changes.update(java_changes)

    application_yml = backend / "application/src/main/resources/application.yml"
    changes[application_yml] = remove_yaml_child(read(application_yml), "usage-logging")

    replit_yml = backend / "application/src/main/resources/application-replit.yml"
    changes[replit_yml] = remove_yaml_child(read(replit_yml), "usage-logging")

    test_yml = backend / "application/src/test/resources/application-test.yml"
    changes[test_yml] = remove_yaml_child(read(test_yml), "usage-logging")

    compose = root / "docker-compose.yml"
    compose_text = read(compose)
    compose_text, compose_count = re.subn(
        r"^[ \t]*USAGE_LOG(?:GING)?_[A-Z_]+:.*\n",
        "",
        compose_text,
        flags=re.MULTILINE,
    )
    if compose_count < 1:
        raise RuntimeError("usage-logging environment entries are missing from docker-compose.yml")
    changes[compose] = compose_text

    env_file = root / ".env.example"
    env_text = read(env_file)
    env_text = replace_once(
        env_text,
        r"\n# -- Usage logging.*?(?=\n# -- JVM)",
        "\n",
        "usage-logging environment section",
    )
    changes[env_file] = env_text

    migrations_resources = backend / "migrations/src/main/resources"
    master = migrations_resources / "db/changelog/db.changelog-master.xml"
    usage_migration = migrations_resources / "db/changelog/changes/0001-usage-events.xml"
    master_text = replace_once(
        read(master),
        r"\n[ \t]*<include file=\"db/changelog/changes/0001-usage-events\.xml\"/>",
        "",
        "usage-events changelog include",
    )
    downstream = find_active_token_references(
        migrations_resources,
        master,
        master_text,
        {usage_migration},
        "usage_events",
    )
    if downstream:
        raise RuntimeError(
            "active Liquibase changelogs still depend on usage_events. "
            "Remove or replace those migrations deliberately first:\n  "
            + "\n  ".join(downstream)
        )
    changes[master] = master_text

    delete_paths = (
        module,
        usage_migration,
        *sorted(bigquery_sink_dirs),
    )
    for path in delete_paths:
        if not path.exists():
            raise RuntimeError(f"required usage-logging path is missing: {path}")

    return changes, delete_paths


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()

    try:
        changes, delete_paths = prepare(root)
    except RuntimeError as error:
        print(f"remove-usage-logging: BLOCKED — {error}", file=sys.stderr)
        return 1

    print("remove-usage-logging: validated MVP telemetry removal")
    for path in changes:
        print(f"  modify {path.relative_to(root)}")
    for path in delete_paths:
        print(f"  remove {path.relative_to(root)}")
    if not args.apply:
        print("remove-usage-logging: DRY RUN — re-run with --apply")
        return 0

    for path, content in changes.items():
        path.write_text(content, encoding="utf-8")
    for path in delete_paths:
        if path.is_dir():
            shutil.rmtree(path)
        else:
            path.unlink()

    print("remove-usage-logging: removed module, call sites, configuration, and migration")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
