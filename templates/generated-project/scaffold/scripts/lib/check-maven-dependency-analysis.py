#!/usr/bin/env python3
"""Prevent Maven dependency analysis from being weakened or silently removed."""
from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path


backend = Path(sys.argv[1] if len(sys.argv) > 1 else "backend")
pom = backend / "pom.xml"
policy = backend / "DEPENDENCY-ANALYSIS.md"
if not pom.is_file():
    print("check-maven-dependency-analysis: passed (no backend pom)")
    raise SystemExit(0)
if not policy.is_file():
    print(f"check-maven-dependency-analysis: missing policy: {policy}", file=sys.stderr)
    raise SystemExit(1)

tree = ET.parse(pom)
root = tree.getroot()


def child(element: ET.Element, local_name: str) -> ET.Element | None:
    return next((node for node in element if node.tag.rsplit("}", 1)[-1] == local_name), None)


def text(element: ET.Element | None, local_name: str) -> str:
    node = child(element, local_name) if element is not None else None
    return (node.text or "").strip() if node is not None else ""


plugins = [node for node in root.iter() if node.tag.rsplit("}", 1)[-1] == "plugin"]
dependency_plugins = [
    plugin for plugin in plugins
    if text(plugin, "groupId") == "org.apache.maven.plugins" and text(plugin, "artifactId") == "maven-dependency-plugin"
]
if not dependency_plugins:
    print("check-maven-dependency-analysis: maven-dependency-plugin is required", file=sys.stderr)
    raise SystemExit(1)

# The parent activates a short plugin entry under build/plugins and keeps the
# configured execution under pluginManagement. Both are required: configuration
# alone does nothing unless the root build activates the managed plugin.
build = child(root, "build")
active_plugins = child(build, "plugins")
is_activated = any(
    text(plugin, "groupId") == "org.apache.maven.plugins" and text(plugin, "artifactId") == "maven-dependency-plugin"
    for plugin in (list(active_plugins) if active_plugins is not None else [])
)
if not is_activated:
    print("check-maven-dependency-analysis: root build/plugins must activate maven-dependency-plugin", file=sys.stderr)
    raise SystemExit(1)

analysis_configuration: ET.Element | None = None
for dependency_plugin in dependency_plugins:
    executions = child(dependency_plugin, "executions")
    if executions is None:
        continue
    for execution in executions:
        if execution.tag.rsplit("}", 1)[-1] != "execution":
            continue
        goals = child(execution, "goals")
        has_analyze_only = goals is not None and any(
            goal.tag.rsplit("}", 1)[-1] == "goal" and (goal.text or "").strip() == "analyze-only"
            for goal in goals
        )
        if has_analyze_only and text(execution, "phase") == "verify":
            analysis_configuration = child(execution, "configuration")
            break
    if analysis_configuration is not None:
        break
if analysis_configuration is None:
    print("check-maven-dependency-analysis: analyze-only must be bound to verify with execution configuration", file=sys.stderr)
    raise SystemExit(1)

if text(analysis_configuration, "failOnWarning").lower() != "true" or text(analysis_configuration, "ignoreNonCompile").lower() != "true":
    print("check-maven-dependency-analysis: failOnWarning=true and ignoreNonCompile=true are required", file=sys.stderr)
    raise SystemExit(1)

policy_text = policy.read_text(encoding="utf-8")
for ignore in analysis_configuration.iter():
    if ignore.tag.rsplit("}", 1)[-1] != "ignoredUnusedDeclaredDependency":
        continue
    coordinate = (ignore.text or "").strip()
    if coordinate and coordinate not in policy_text:
        print(f"check-maven-dependency-analysis: undocumented ignore: {coordinate}", file=sys.stderr)
        raise SystemExit(1)

print("check-maven-dependency-analysis: passed")
