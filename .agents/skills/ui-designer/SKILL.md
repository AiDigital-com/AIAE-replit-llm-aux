---
name: ui-designer
description: Design or refine React UI within the installed visual system while preserving product behavior. Use for new UI, visual-polish passes, responsive/accessibility work, or exact migration parity; explicitly select parity, improve, or new-design mode before editing.
---

# UI Designer

Work as a product designer and frontend engineer. Preserve business logic,
authorization, API contracts, query ownership, and auth while changing UI.

## Select one mode

- `PARITY`: reproduce an approved original exactly. Do not add creative changes;
  compare equivalent data, states, viewports, icons, copy, and animations.
- `IMPROVE`: keep the established visual language and navigation while fixing
  hierarchy, consistency, accessibility, responsiveness, and incomplete states.
- `NEW`: establish a direction grounded in the product, audience, and task before
  coding. Avoid generic AI visual defaults and decorative elements without a job.

If the request does not make the mode clear, infer it from context and state the
choice before substantial edits.

## Workflow

1. Read `frontend_style.md`, `40-frontend-rules.md`, the canonical token source,
   and the relevant components/data states.
2. Inventory required states: loading, empty, error, content, disabled, denied,
   pending, success, long content, mobile, and desktop.
3. For `PARITY`, map original to target component/state and capture baselines.
   For `IMPROVE`/`NEW`, define a compact direction: audience, page job, hierarchy,
   token changes, layout, and one justified signature treatment at most.
4. Implement with existing primitives and icon library. Extend semantic tokens
   rather than hardcoding component colors. Keep one primary CTA per view.
5. Preserve navigation and avoid nested cards, overlapping text, viewport-scaled
   fonts, inaccessible icon buttons, and animation without reduced-motion support.
6. Render and inspect screenshots at mobile and desktop widths. Check focus,
   overflow, console errors, and key interactions. For parity, produce a diff and
   explain every remaining delta.
7. Run typecheck, tests, and build required by the repository, then use
   `frontend-style-review` as the read-only gate.

## Content and motion

- Use interface copy to explain actions and outcomes, not implementation details.
- Keep action naming consistent through button, progress, and success messages.
- Make empty/error states actionable and specific.
- Use motion to communicate state or hierarchy. Prefer one coordinated moment to
  scattered effects; respect `prefers-reduced-motion`.

## Output

Before editing, state mode and affected screens. After editing, report files,
validated states/viewports, commands, screenshot evidence, and remaining deltas.
