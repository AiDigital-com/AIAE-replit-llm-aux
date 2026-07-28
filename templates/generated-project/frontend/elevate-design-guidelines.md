# Elevate Design Guidelines

Single source of truth for generated React product UI. This is adapted from
the Elevate brand/visual system document into this template's plain CSS + BEM
frontend stack.

## Personality

Clean, utilitarian, and data-dense by design. Generated apps are internal tools,
not marketing pages. The UI should feel quiet, precise, and ready for repeated
workflows.

## Layout Rules

- No left side menu, sidebar, side rail, or permanent left navigation.
- Use a top app header, page-level tabs, segmented controls, filters, and local
  toolbars instead.
- Keep content centered in a max-width content shell: `79.0625rem` max width
  with `1.5rem` horizontal page padding.
- Use flexbox for one-dimensional layout and CSS grid only for
  two-dimensional/table-like layouts such as multi-column forms and data rows.
  Four-column forms use `repeat(4, minmax(0, 1fr))` and collapse at responsive
  breakpoints.
- Prefer dense tables, search bars, grouped rows, filters, and compact page
  headers over oversized hero sections.
- One primary CTA per view. Secondary actions use outline, ghost, menu, or icon
  buttons.

## Tokens

All colors live in `frontend/src/shared/ui/base/tokens.css` as CSS custom
properties. Components consume semantic tokens. Do not hard-code hex or HSL in
feature/component CSS files.

| Token | HSL | Use |
|---|---:|---|
| `--primary` | `239 100% 43%` | primary CTA, links, focus ring |
| `--background` | `0 0% 100%` | page background |
| `--foreground` | `0 0% 4%` | body text |
| `--secondary` | `240 78% 98%` | cards, search, table surfaces |
| `--accent` | `237 76% 94%` | table headers, chips, hover rows |
| `--muted-foreground` | `0 0% 54%` | secondary copy |
| `--label-muted` | `226 25% 68%` | section labels |
| `--header-text` | `230 17% 22%` | heavy headings |
| `--border` | `237 76% 94%` | dividers, strokes, gridlines |

Status colors are reserved only for state communication:

| State | HSL | Use |
|---|---:|---|
| `--status-success` | `134 100% 30%` | live/success |
| `--status-info` | `234 100% 43%` | paused/informational |
| `--status-warning` | `52 100% 37%` | moderation/warning |
| `--status-draft` | `0 0% 28%` | archived/draft |
| `--status-error` | `0 72% 45%` | rejected/destructive |

Never use status colors as decoration.

### Scale tokens (spacing, radius, type)

`tokens.css` also exposes spacing, radius, and type scales as CSS variables —
consume these in component CSS instead of hard-coding raw units:

- Spacing: `--space-1` (`0.25rem`), `--space-2` (`0.5rem`),
  `--space-3` (`0.75rem`), `--space-4` (`1rem`),
  `--space-6` (`1.5rem`), `--space-10` (`2.5rem`).
- Radius: `--radius-sm` (`0.5rem`), `--radius-md` (`0.625rem`),
  `--radius-lg`/`--radius-xl` (`0.75rem`),
  `--radius-full` (`999rem`).
- Type: `--text-body` (`0.8125rem`), `--text-table-head` (`0.875rem`),
  `--text-subhead` (`1rem`), `--text-section` (`1.125rem`),
  `--text-page-title` (`2rem`); aliases
  `--text-sm`/`--text-base`/`--text-lg`/`--text-xl`.
- Layout/control: `--content-max-width` (`79.0625rem`) and
  `--control-height` (`2.5rem`).
- Surface/text/border aliases: `--surface-default`, `--surface-muted`,
  `--surface-accent`, `--text-default`, `--text-muted`, `--accent-primary`,
  `--border-default`.

Runtime CSS under `frontend/src` uses `rem` tokens, not raw `px`. Pixel values
from design specs must be converted into tokens before use.

## Typography

- Primary typeface: Inter, weights 400, 500, 600, 700.
- Poppins 500 is reserved for rare display moments only.
- Product surfaces use compact type:
  - page title: `2rem / 700`
  - section H2: `1.125rem / 600`
  - subhead: `1rem / 500`
  - body: `0.8125rem / 400`
  - table head: `0.875rem / 500`
  - pill: `0.75rem / 400`
  - badge: `0.6875rem / 600`, uppercase
- Body copy in product surfaces must stay between `0.75rem` and `1rem`.

## Shape and Spacing

- Base radius: `0.75rem`.
- Controls: `0.625rem`; compact elements: `0.5rem`; pills: `999rem`.
- Common spacing increments: `0.375rem`, `0.5rem`, `0.75rem`, `1rem`,
  `1.5rem`, `2.5rem`.
- Table/list rows use `1rem` gaps and `1.5rem` horizontal padding when space
  allows.

## Components

- Buttons: primary button is at least `2.5rem` tall, `0.625rem` radius,
  `0.875rem / 500`, and centered with inline-flex so labels wrap cleanly.
- Rounded-full pill buttons are exceptions for floating card/chart actions,
  onboarding, empty states, and modal confirmations. Never use two pill buttons
  in one view.
- Inputs: at least `2.5rem` tall, `0.625rem` radius, semantic
  border/background tokens.
- Status pills: rounded-full, state token only, concise labels.
- Tables: lavender header via accent token, secondary surface for grouped rows,
  expanded child rows use accent for contrast.
- User-entered/API-rendered text must not break layout: text containers use
  `min-width: 0`/`min-inline-size: 0` and `overflow-wrap: anywhere`; controls
  and media cap at `max-inline-size: 100%`.

## Authentication Surface

- Treat login as part of the product, not an unstyled identity-provider embed.
- Use a responsive, vertically and horizontally centered auth surface by default.
  If the approved product design defines another composition, preserve it.
- Keep the form container focused and restrained: one heading, short supporting
  copy, semantic border/surface/shadow tokens, and no unrelated dashboard chrome.
- Style Clerk through its supported `appearance` API. Validate sign-in, sign-up,
  verification, CAPTCHA, loading, and error states at mobile and desktop widths.
- Clerk remains the only auth implementation; visual customization must not
  recreate password handling or bypass provider flows.

## Charts

Charts live inside cards. Use a secondary header strip, white plot area,
`1.5rem` internal padding, muted tick labels, and dotted border-token gridlines.

Categorical series use this order:

1. primary `239 100% 43%`
2. cyan `190 65% 54%`
3. lime `76 75% 60%`
4. purple `263 47% 58%`
5. pink `319 75% 77%`
6. grey `0 0% 72%`
7. sky `219 74% 52%`
8. magenta `346 69% 52%`

Assign the largest segment to primary.

## Do / Do Not

Do:
- use semantic tokens,
- keep one primary CTA per view,
- use secondary/accent surfaces for tables, filters, and row states,
- keep data dense but readable,
- use BEM classes and plain CSS.

Do not:
- create a left side menu/sidebar,
- hard-code colors in components,
- introduce new accent colors without extending tokens,
- use status colors for non-status UI,
- mix unrelated radius scales such as `0.25rem` and `1.25rem`,
- place multiple primary buttons in one row.
