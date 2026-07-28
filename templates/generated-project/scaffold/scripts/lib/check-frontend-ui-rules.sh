#!/usr/bin/env bash
#
# check-frontend-ui-rules.sh — rejects generated frontend UI rule drift.
#
# Usage:
#   bash scripts/lib/check-frontend-ui-rules.sh [frontend_src_root...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCAFFOLD_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [ "$#" -eq 0 ]; then
  cd "${SCAFFOLD_ROOT}"
  if [ -d frontend/src ]; then
    set -- frontend/src
  fi
else
  cd "${PROJECT_ROOT:-$(pwd)}"
fi

if [ "$#" -eq 0 ]; then
  echo "check-frontend-ui-rules: no frontend source directories to scan"
  exit 0
fi

python3 - "$@" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path


CSS_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)
RAW_PX = re.compile(r"(?<![A-Za-z0-9_-])(?:\d+\.\d+|\d+|\.\d+)px\b")
HEX_COLOR = re.compile(r"#[0-9a-fA-F]{3,8}\b")
FOUR_COLUMN_GRID = re.compile(r"grid-template-columns\s*:\s*repeat\(\s*4\s*,", re.IGNORECASE)
FORM_TAG = re.compile(r"<form\b", re.IGNORECASE)


def strip_css_comments(text: str) -> str:
    return CSS_COMMENT.sub("", text)


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def css_block(text: str, selector: str) -> str | None:
    match = re.search(rf"(^|\n)\s*{re.escape(selector)}\s*\{{(?P<body>.*?)\n\s*\}}", text, re.DOTALL)
    if not match:
        return None
    return match.group("body")


def declaration_present(block: str, property_name: str, value: str) -> bool:
    pattern = re.compile(rf"\b{re.escape(property_name)}\s*:\s*{re.escape(value)}\s*(?:;|\n|$)")
    return bool(pattern.search(block))


def scan_css(path: Path) -> list[str]:
    raw_text = path.read_text(encoding="utf-8")
    text = strip_css_comments(raw_text)
    violations: list[str] = []
    for match in RAW_PX.finditer(text):
        violations.append(f"{path}:{line_number(text, match.start())}: use rem/token units instead of raw px")
    for match in HEX_COLOR.finditer(text):
        violations.append(f"{path}:{line_number(text, match.start())}: use semantic CSS tokens instead of hard-coded hex colors")
    if FOUR_COLUMN_GRID.search(text) and "@media" not in text:
        violations.append(f"{path}: four-column grid must define a responsive @media collapse")
    return violations


def scan_reset(root: Path) -> list[str]:
    reset = root / "shared" / "ui" / "base" / "reset.css"
    if not reset.is_file():
        return [f"{reset}: missing base reset.css with overflow/button safeguards"]

    text = strip_css_comments(reset.read_text(encoding="utf-8"))
    violations: list[str] = []

    body = css_block(text, "body")
    if body is None or not declaration_present(body, "overflow-wrap", "anywhere"):
        violations.append(f"{reset}: body must set overflow-wrap: anywhere for long user/API strings")

    button = css_block(text, "button")
    required_button_declarations = {
        "display": "inline-flex",
        "align-items": "center",
        "justify-content": "center",
        "text-align": "center",
        "max-inline-size": "100%",
        "min-inline-size": "0",
    }
    if button is None:
        violations.append(f"{reset}: button reset block is required")
    else:
        for property_name, value in required_button_declarations.items():
            if not declaration_present(button, property_name, value):
                violations.append(f"{reset}: button must set {property_name}: {value}")

    return violations


def scan_forms(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    if not FORM_TAG.search(text):
        return []

    checks = {
        "required or aria-required on mandatory fields": re.compile(r"\b(required|aria-required=)", re.IGNORECASE),
        "aria-invalid on validated controls": re.compile(r"\baria-invalid=", re.IGNORECASE),
        "linked or announced validation errors": re.compile(r"\b(role=[\"']alert[\"']|aria-describedby=)", re.IGNORECASE),
    }
    violations = []
    for message, pattern in checks.items():
        if not pattern.search(text):
            violations.append(f"{path}: form must include {message}")
    return violations


def main() -> int:
    roots = [Path(arg) for arg in sys.argv[1:]]
    violations: list[str] = []

    for root in roots:
        if not root.is_dir():
            continue
        for css_path in sorted(root.rglob("*.css")):
            violations.extend(scan_css(css_path))
        violations.extend(scan_reset(root))
        for tsx_path in sorted(root.rglob("*.tsx")):
            violations.extend(scan_forms(tsx_path))

    if violations:
        print(f"check-frontend-ui-rules: FAIL — {len(violations)} violation(s):", file=sys.stderr)
        for violation in violations:
            print(f"  {violation}", file=sys.stderr)
        return 1

    print(f"check-frontend-ui-rules: OK ({len(roots)} frontend source tree(s) scanned)")
    return 0


raise SystemExit(main())
PY
