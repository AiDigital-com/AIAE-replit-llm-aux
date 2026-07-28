---
name: frontend-style-review
description: Review changed React frontend code for behavior, visual consistency, accessibility, responsive layout, request efficiency, and installed frontend-rule compliance. Use after frontend changes, before commit/PR, for UI parity checks, or when asked to audit CSS, TanStack Query, Clerk, or OpenAPI client usage.
---

# Frontend Style Review

Perform a read-only review. Treat frontend correctness as behavior plus visual
output plus network behavior, not merely CSS naming.

## Inputs

1. Read `CLAUDE.md`, `.claude/rules/40-frontend-rules.md`,
   `.claude/agent_docs/frontend_architecture.md`, and `frontend_style.md`.
2. Establish scope from requested files, diff/range, or the whole frontend.
3. Determine whether the task is visual parity, a constrained improvement, or a
   new design. Review against that mode; do not reward redesign during parity.

## Review sequence

1. Inspect component logic, styles, query hooks, and tests together.
2. Check behavior and states: loading, error, empty, success, disabled, denied,
   mutation pending/success/failure, and long-content handling.
3. Check data behavior:
   - typed shared OpenAPI client only;
   - one canonical query-key owner per resource;
   - no equivalent duplicate requests;
   - inactive/dependent UI does not fetch unnecessarily;
   - mutations update authoritative cache or narrowly invalidate;
   - user-scoped cache clears on sign-out/account switch.
4. Check UI implementation:
   - established navigation and design system remain intact;
   - BEM/plain CSS/token rules are followed;
   - icons, labels, spacing, and interaction states match the approved source;
   - no overlap or overflow at supported widths;
   - keyboard focus, semantics, contrast, reduced motion, and touch access work.
5. When runtime access exists, inspect desktop/mobile screenshots, console, and
   network requests. Static source review alone cannot prove visual parity.
6. Map behavior to existing tests and request-count assertions when relevant.

Useful discovery scans:

```bash
grep -rnE "\b(fetch|axios|XMLHttpRequest)\b|http://localhost" frontend/src | grep -v "shared/api/client"
grep -rnE "tailwind|styled-components|@emotion|\.module\.css" frontend/src frontend/package.json
grep -rnE "#[0-9a-fA-F]{3,6}|hsl\(|rgb\(" frontend/src/features frontend/src/shared | grep -v tokens.css
git -C frontend diff --name-only -- src/shared/api/generated/schema.d.ts
```

Scanner output is evidence to inspect, not an automatic violation.

## Finding threshold and output

Report only findings with confidence at least 80/100. Order by user impact:

```text
STATUS: PASS | CHANGES_REQUESTED
Scope: <files/routes/states/viewports>
Verification: <tests/build/browser/network evidence, or gaps>
Findings:
- [BLOCKING|IMPORTANT|MINOR, confidence] file:line - problem - impact - fix
```

If no qualifying findings exist, state that clearly and identify any unverified
runtime, viewport, role, or network state.
