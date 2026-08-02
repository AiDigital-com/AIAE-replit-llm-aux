#!/usr/bin/env python3
"""Remove the scaffold's complete cache stack as one validated transaction."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from liquibase_dependency_guard import find_active_token_references
from removal_transaction import apply_removal_transaction


CACHE_USE = re.compile(
    r"@(?:Cacheable|CachePut|CacheEvict|CacheConfig)\b"
    r"|@(?:org\.hibernate\.annotations\.Cache|jakarta\.persistence\.Cacheable)\b"
    r"|\bHINT_[A-Z0-9_]*CACHE[A-Z0-9_]*\b"
    r"|\bsetCache(?:able|Region|Mode)\s*\("
    r"|\b(?:CacheMode|NaturalIdCache)\b"
    r"|CacheInvalidationEvent"
    r"|CacheNamesByClass"
    r"|CacheUpdaterService"
    r"|publishUpdateEvent\s*\("
)
DIRECT_CACHE_API_USE = re.compile(
    r"\b(?:javax|jakarta)\.cache\."
    r"|\borg\.springframework\.cache\."
    r"|\borg\.ehcache\."
    r"|\borg\.hibernate\.cache\."
    r"|\bimport\s+org\.hibernate\.annotations\."
    r"(?:Cache|CacheConcurrencyStrategy|NaturalIdCache)\s*;"
    r"|\bimport\s+(?:javax|jakarta)\.persistence\.Cache\s*;"
    r"|\bgetCache\s*\("
    r"|@EnableCaching\b"
)
CACHE_LITERAL_USE = re.compile(
    r"[\"'](?:javax|jakarta)\.persistence\.cache\."
    r"(?:retrieveMode|storeMode)[\"']"
    r"|[\"']org\.hibernate\.(?:cacheable|cacheRegion|cacheMode)[\"']"
)
JAVA_COMMENT_OR_LITERAL = re.compile(
    r"//[^\n]*|/\*.*?\*/|\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'",
    re.MULTILINE | re.DOTALL,
)


def java_code_only(text: str) -> str:
    return JAVA_COMMENT_OR_LITERAL.sub(
        lambda match: "".join("\n" if char == "\n" else " " for char in match.group()),
        text,
    )


def read(path: Path) -> str:
    if not path.is_file():
        raise RuntimeError(f"required file is missing: {path}")
    return path.read_text(encoding="utf-8")


def find_one(root: Path, pattern: str) -> Path:
    matches = tuple(root.rglob(pattern))
    if len(matches) != 1:
        raise RuntimeError(
            f"expected exactly one path matching {pattern} under {root}; found {len(matches)}"
        )
    return matches[0]


def replace_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE | re.DOTALL)
    if count != 1:
        raise RuntimeError(f"expected exactly one {label}; found {count}")
    return updated


def remove_dependency(text: str, group: str, artifact: str, label: str) -> str:
    pattern = (
        r"\n[ \t]*<dependency>\s*"
        rf"<groupId>{re.escape(group)}</groupId>\s*"
        rf"<artifactId>{re.escape(artifact)}</artifactId>"
        r".*?</dependency>"
    )
    return replace_once(text, pattern, "", label)


def remove_yaml_children(text: str, parent: str, children: tuple[str, ...]) -> str:
    """Remove exact direct children from a YAML mapping without touching siblings."""
    lines = text.splitlines(keepends=True)
    parent_matches = [
        index
        for index, line in enumerate(lines)
        if re.fullmatch(rf"{re.escape(parent)}:\s*(?:#.*)?\n?", line)
    ]
    if len(parent_matches) != 1:
        raise RuntimeError(
            f"expected exactly one top-level {parent} mapping; found {len(parent_matches)}"
        )

    parent_start = parent_matches[0]
    parent_end = len(lines)
    for index in range(parent_start + 1, len(lines)):
        line = lines[index]
        stripped = line.strip()
        if stripped and not stripped.startswith("#") and len(line) - len(line.lstrip()) == 0:
            parent_end = index
            break

    blocks: list[tuple[int, int, str]] = []
    for child in children:
        child_matches = [
            index
            for index in range(parent_start + 1, parent_end)
            if re.fullmatch(rf"  {re.escape(child)}:\s*(?:#.*)?\n?", lines[index])
        ]
        if len(child_matches) != 1:
            raise RuntimeError(
                f"expected exactly one {parent}.{child} mapping; found {len(child_matches)}"
            )

        start = child_matches[0]
        end = parent_end
        for index in range(start + 1, parent_end):
            line = lines[index]
            stripped = line.strip()
            indent = len(line) - len(line.lstrip())
            if stripped and not stripped.startswith("#") and indent <= 2:
                end = index
                break
        blocks.append((start, end, child))

    for start, end, _ in sorted(blocks, reverse=True):
        del lines[start:end]
    return "".join(lines)


def prepare_changes(root: Path) -> tuple[dict[Path, str], tuple[Path, ...]]:
    backend = root / "backend"
    if not (backend / "pom.xml").is_file():
        raise RuntimeError(f"not a generated full-stack project: {backend / 'pom.xml'} is missing")

    cache_owned_files = (
        find_one(backend / "application/src/main/java", "cache/CacheConfig.java"),
        find_one(backend / "application/src/main/java", "cache/CacheProperties.java"),
        find_one(backend / "application/src/main/java", "cache/CacheWarmUpService.java"),
        find_one(
            backend / "application/src/test/java", "cache/CacheInvalidationIntegrationTest.java"
        ),
        find_one(backend / "application/src/test/java", "cache/CacheWarmUpServiceTest.java"),
        find_one(
            backend / "service/src/main/java",
            "service/cache/ApplicationCacheNamesByClassRegistry.java",
        ),
        find_one(
            backend / "service/src/main/java",
            "service/cache/JpaCacheInvalidationEventService.java",
        ),
        find_one(
            backend / "service/src/test/java",
            "service/cache/JpaCacheInvalidationEventServiceTest.java",
        ),
        find_one(
            backend / "domain/src/main/java",
            "domain/cache/entities/CacheInvalidationEventEntity.java",
        ),
        find_one(
            backend / "domain/src/main/java",
            "domain/cache/repositories/CacheInvalidationEventRepository.java",
        ),
    )

    unexpected: list[str] = []
    for java_file in backend.rglob("*.java"):
        if java_file.is_relative_to(backend / "cache-management") or java_file in cache_owned_files:
            continue
        original = java_file.read_text(encoding="utf-8")
        source = java_code_only(original)
        match = (
            CACHE_USE.search(source)
            or DIRECT_CACHE_API_USE.search(source)
            or CACHE_LITERAL_USE.search(original)
        )
        if match:
            line = source.count("\n", 0, match.start()) + 1
            unexpected.append(f"{java_file.relative_to(root).as_posix()}:{line}")
    if unexpected:
        details = "\n  ".join(unexpected)
        raise RuntimeError(
            "application cache usage exists outside the removable scaffold wiring; "
            "keep the cache stack or remove those usages deliberately first:\n  "
            + details
        )

    remaining_service_source = "\n".join(
        read(path)
        for path in (backend / "service/src/main/java").rglob("*.java")
        if path not in cache_owned_files
    )
    remaining_domain_source = "\n".join(
        read(path)
        for path in (backend / "domain/src/main/java").rglob("*.java")
        if path not in cache_owned_files
    )
    remaining_application_source = "\n".join(
        read(path)
        for path in (backend / "application/src/main/java").rglob("*.java")
        if path not in cache_owned_files
    )

    changes: dict[Path, str] = {}

    architecture = root / "docs/architecture-overview.md"
    architecture_text = read(architecture)
    architecture_text = replace_once(
        architecture_text,
        r"^- Cache status: enabled$",
        "- Cache status: disabled",
        "enabled architecture cache status",
    )
    architecture_text = replace_once(
        architecture_text,
        r"^\| `backend/cache-management` \|[^\n]*\n",
        "",
        "cache-management architecture module row",
    )
    changes[architecture] = architecture_text

    parent = backend / "pom.xml"
    parent_text = read(parent)
    parent_text = replace_once(
        parent_text,
        r"\n[ \t]*<module>cache-management</module>",
        "",
        "cache-management module declaration",
    )
    parent_text = remove_dependency(
        parent_text,
        "${project.groupId}",
        "cache-management",
        "managed cache-management dependency",
    )
    parent_text = replace_once(
        parent_text,
        r"\n  Keep cache-management only with the complete cache stack\.",
        "",
        "cache-management parent-module documentation",
    )
    changes[parent] = parent_text

    service_pom = backend / "service/pom.xml"
    service_text = remove_dependency(
        read(service_pom),
        "${project.groupId}",
        "cache-management",
        "service cache-management dependency",
    )
    if "org.springframework.data." not in remaining_service_source:
        service_text = remove_dependency(
            service_text,
            "org.springframework.data",
            "spring-data-commons",
            "service paging dependency used by cache invalidation",
        )
    if "org.springframework.transaction." not in remaining_service_source:
        service_text = remove_dependency(
            service_text,
            "org.springframework",
            "spring-tx",
            "service transaction dependency used by cache invalidation",
        )
    if "org.slf4j." not in remaining_service_source:
        service_text = remove_dependency(
            service_text,
            "org.slf4j",
            "slf4j-api",
            "service logging dependency used by cache invalidation",
        )
    changes[service_pom] = service_text

    domain_pom = backend / "domain/pom.xml"
    domain_text = read(domain_pom)
    if "org.springframework.data.domain." not in remaining_domain_source:
        domain_text = remove_dependency(
            domain_text,
            "org.springframework.data",
            "spring-data-commons",
            "domain paging dependency used by cache invalidation",
        )
    changes[domain_pom] = domain_text

    application_pom = backend / "application/pom.xml"
    application_text = read(application_pom)
    cache_dependencies = (
        ("${project.groupId}", "cache-management", "application cache-management dependency"),
        ("javax.cache", "cache-api", "JCache API dependency"),
        ("org.ehcache", "ehcache", "Ehcache runtime dependency"),
        ("org.hibernate.orm", "hibernate-jcache", "Hibernate JCache dependency"),
        ("org.springframework.boot", "spring-boot-starter-cache", "Spring cache starter"),
    )
    for group, artifact, label in cache_dependencies:
        application_text = remove_dependency(application_text, group, artifact, label)
    if not re.search(r"\bimport\s+[\w.]+\.domain\.", remaining_application_source):
        application_text = remove_dependency(
            application_text,
            "${project.groupId}",
            "domain",
            "direct domain dependency used by application cache wiring",
        )
    if "org.springframework.cache." not in remaining_application_source:
        application_text = remove_dependency(
            application_text,
            "org.springframework",
            "spring-context-support",
            "Spring cache support dependency",
        )
    application_text = replace_once(
        application_text,
        r"\n[ \t]*<ignoredNonTestScopedDependency>\s*"
        r"\$\{project\.groupId}:cache-management\s*"
        r"</ignoredNonTestScopedDependency>",
        "",
        "cache-management dependency-analyzer exception",
    )
    changes[application_pom] = application_text

    application_yml = backend / "application/src/main/resources/application.yml"
    yml = read(application_yml)
    yml = replace_once(
        yml,
        r"\n  cache:\n    type: jcache\n",
        "\n",
        "spring.cache block",
    )
    yml = replace_once(
        yml,
        r"\n        # Second-level cache configuration\..*?"
        r"\n  liquibase:",
        "\n  liquibase:",
        "Hibernate L2/JCache block",
    )
    yml = remove_yaml_children(yml, "app", ("cache", "cache-management"))
    changes[application_yml] = yml

    migrations_resources = backend / "migrations/src/main/resources"
    master = migrations_resources / "db/changelog/db.changelog-master.xml"
    cache_migration = (
        migrations_resources / "db/changelog/changes/0003-cache-invalidation.xml"
    )
    master_text = replace_once(
        read(master),
        r"\n[ \t]*<include file=\"db/changelog/changes/0003-cache-invalidation\.xml\"/>",
        "",
        "cache invalidation changelog include",
    )
    downstream = find_active_token_references(
        migrations_resources,
        master,
        master_text,
        {cache_migration},
        "cache_invalidation_event",
    )
    if downstream:
        raise RuntimeError(
            "active Liquibase changelogs still depend on cache_invalidation_event. "
            "Remove or replace those migrations deliberately first:\n  "
            + "\n  ".join(downstream)
        )
    changes[master] = master_text

    delete_paths = (
        backend / "cache-management",
        *cache_owned_files,
        backend / "application/src/main/resources/ehcache.xml",
        cache_migration,
    )
    for path in delete_paths:
        if not path.exists():
            raise RuntimeError(f"required cache-owned path is missing: {path}")

    residual: list[str] = []
    for token in ("cache-management", "0003-cache-invalidation.xml"):
        for candidate in backend.rglob("*"):
            if "target" in candidate.parts or not candidate.is_file():
                continue
            if any(candidate == deleted or candidate.is_relative_to(deleted) for deleted in delete_paths):
                continue
            content = changes.get(candidate)
            if content is None:
                content = candidate.read_text(encoding="utf-8", errors="ignore")
            if token in content:
                residual.append(candidate.relative_to(root).as_posix())
    if residual:
        raise RuntimeError(
            "planned no-cache tree still has active references:\n  "
            + "\n  ".join(sorted(set(residual)))
        )

    return changes, delete_paths


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()

    try:
        changes, delete_paths = prepare_changes(root)
    except (RuntimeError, StopIteration) as error:
        print(f"remove-cache-management: BLOCKED — {error}", file=sys.stderr)
        return 1

    print("remove-cache-management: validated complete no-cache transformation")
    for path in changes:
        print(f"  modify {path.relative_to(root)}")
    for path in delete_paths:
        print(f"  remove {path.relative_to(root)}")

    if not args.apply:
        print("remove-cache-management: DRY RUN — re-run with --apply")
        return 0

    try:
        apply_removal_transaction(root, changes, delete_paths)
    except (OSError, RuntimeError) as error:
        print(f"remove-cache-management: FAILED — {error}", file=sys.stderr)
        return 1

    print("remove-cache-management: removed L2 cache and cross-node invalidation together")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
