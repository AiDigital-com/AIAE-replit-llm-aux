# Frontend Style And BEM Rules

This is the reusable visual contract for React frontends using the AI Digital /
Elevate design system: indigo primary (`hsl(239 100% 43%)`) with restrained
neutral/lavender surfaces, expressed through semantic tokens. Preserve an
existing project's approved brand palette and navigation model when they differ;
do not redesign either as part of unrelated work.

## Personality

Clean, utilitarian, and data-dense. This is an internal operations tool, not a
marketing page. The UI should feel quiet, precise, and built for repeated
workflows.

## Layout

- Preserve the navigation shell already selected by the product: header, tabs,
  left navigation, or another documented model. Do not introduce or remove a
  permanent sidebar during an unrelated feature/style change.
- Navigation renders only destinations available to the current user's access
  model and keeps account/sign-out controls in the established shell location.
- Each page owns a compact `page-header` (title + subtitle + optional status),
  then dense content (tables, filters, grouped rows) — not oversized hero
  sections.
- One primary CTA per view. Secondary actions use `button--secondary`,
  `button--ghost`, menu, or icon buttons. Never two primary buttons in one row.

## Design tokens

All colors and scale values live in the project's canonical token stylesheet as
CSS custom properties; components consume semantic tokens. Never hard-code
hex/HSL in feature or component CSS. Extend the canonical token source before
introducing a new value.

Current semantic tokens:

| Token | Use |
|---|---|
| `--color-bg` | page background (`hsl(240 60% 99%)`) |
| `--color-panel` | cards, sidebar, table/row surfaces (white) |
| `--color-text` | body text + headings |
| `--color-muted` | secondary copy, labels |
| `--color-border` | dividers, strokes, gridlines |
| `--color-accent` | primary CTA, links, active nav (indigo `hsl(239 100% 43%)`) |
| `--color-accent-hover` | primary button hover/active |
| `--color-accent-contrast` | text/icon on accent |
| `--color-accent-soft` | active nav background, soft notices |
| `--color-surface-muted` | table header / grouped-row surface (lavender) |
| `--color-success-bg` / `--color-success-text` | success/active state |
| `--color-neutral-bg` / `--color-neutral-text` | neutral status pill |
| `--color-danger` / `--color-danger-border` / `--color-danger-bg` | error / destructive |
| `--radius-card` (`0.75rem`) / `--radius-control` (`0.625rem`) / `--radius-pill` | card vs control vs pill radius |
| navigation dimension tokens | established header/sidebar dimensions when the selected shell needs them |

Status colors communicate state only — never use them as decoration. Status pills
use a leading `status__dot` (a `currentColor` dot) so state reads at a glance.
Runtime CSS uses semantic tokens and `rem` units. Raw `px` units and hard-coded
hex colors are forbidden under `frontend/src/**/*.css`.

## Typography

- Primary typeface: Inter, weights 400/500/600/700.
- Compact product type: page title `1.625–2rem / 700`, section H2
  `1.125rem / 600`, subhead `1rem / 500`, body `0.8125–0.875rem / 400`,
  table head `0.75–0.875rem / 700` uppercase for column labels, pill
  `0.75rem`.
- Body copy stays between `0.75rem` and `1rem`.
- Letter spacing stays `0`. No viewport-width font scaling.

## Shape and spacing

- Cards/panels use `--radius-card` (`0.75rem`); controls/buttons/inputs use
  `--radius-control` (`0.625rem`); pills use `--radius-pill` (`999rem`). Do not
  mix unrelated radius scales.
- Common spacing increments are tokenized in rem. Table/list rows use compact
  tokenized vertical and horizontal padding.
- Parent layout blocks own spacing via `gap`/padding; blocks set no external
  margins (see CSS selector rules).

## Components

- Buttons: at least `2.5rem` tall, `--radius-control`, `0.875rem / 600–700`,
  inline-flex centered, wrapping-safe labels. `button` (primary accent),
  `button--secondary`, `button--ghost`.
- Inputs/selects: at least `2.5rem` tall, `--radius-control`, semantic
  border/background.
- Status pills: rounded-full, state token only, concise label.
- Tables: muted header surface (`--color-surface-muted`), `--color-panel` rows,
  grid-based rows with explicit column tracks. Do not nest cards.
- Modals/dialogs: a single block (`*-dialog`) with overlay + panel; one primary
  confirm action.

## Styling baseline

- Use plain CSS files imported by React components.
- Use BEM class names for all project-authored styles.
- Do not introduce CSS Modules, Tailwind, styled-components, Emotion, or CSS-in-JS.
- Design tokens live in CSS custom properties and are consumed by components.
- Do not hardcode new colors in component CSS when a semantic token should exist.
- Use flexbox for one-dimensional layout. Use CSS grid for two-dimensional or
  table-like layout such as data rows and multi-column forms.

## BEM syntax

Use one locked syntax:

```text
block
block__element
block--modifier
block__element--modifier
block--size-large
block__status--state-active
```

Rules:

- lowercase kebab-case inside names
- double underscore between block and element
- double hyphen before modifiers
- single hyphen only inside multi-word names
- modifiers compose with the base class: `button button--secondary`, not only `button--secondary`

Forbidden variants:

- `block_element`
- `block_modifier_value`
- `blockElement`
- ambiguous `block-element` where the separator does not identify element vs modifier

## CSS selector rules

- Prefer flat class selectors.
- Do not use IDs for styling.
- Do not use tag selectors in component CSS.
- Do not use descendant selectors such as `.card .card__title`.
- Blocks should not set external margins. Parent layout blocks own spacing through `gap` or padding.
- Avoid global resets inside feature/component CSS. Base reset and token layers belong in app/shared base CSS.

## File organization

For new or refactored UI, use one block per directory:

```text
frontend/src/features/<feature-name>/<feature-name>.tsx
frontend/src/features/<feature-name>/<feature-name>.css
frontend/src/features/<feature-name>/components/<sub-block>/<sub-block>.tsx
frontend/src/features/<feature-name>/components/<sub-block>/<sub-block>.css
```

The directory name, component CSS file, and root block class should match.

## Class name helper

A tiny local `cn` helper is acceptable for conditional class names. Do not add a dependency such as `clsx` only for this unless the project already uses it.

## UI quality rules

- Use the radius tokens (`--radius-card` `0.75rem`, `--radius-control`
  `0.625rem`); do not introduce ad-hoc radii.
- Use icons for icon-like actions when an icon library is already present.
- Do not create nested cards.
- Text must fit its container on mobile and desktop.
- User/API text containers use `min-width: 0`/`min-inline-size: 0` and
  `overflow-wrap: anywhere`; controls and media cap at `max-inline-size: 100%`.
- Do not use viewport-width font scaling.
- Letter spacing must stay `0` unless a very specific brand treatment already exists.
- Avoid one-note palettes and decorative orb/blob backgrounds.
