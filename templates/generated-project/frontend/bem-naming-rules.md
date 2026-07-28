# BEM Naming Rules (canonical)

BEM methodology for CSS class names. Single source of truth.
Background: https://skillbox.ru/media/code/metodologiya-bem-chto-eto-takoe-i-kak-ona-uproshchaet-zhizn-razrabotchikam/

## Three concepts

| | Name | Meaning |
|---|---|---|
| **B**lock | `block` | Independent, reusable component. Has no semantic dependency on its surroundings. |
| **E**lement | `block__element` | A part that only makes sense inside its block. Cannot exist without its block. |
| **M**odifier | `block--modifier` or `block__element--modifier` | A flag for state, behavior, or appearance. |

## Naming syntax (locked)

- Block: `.user-card`
- Element: `.user-card__avatar`, `.user-card__name`, `.user-card__role`
- Boolean modifier: `.user-card--featured`, `.user-card__avatar--rounded`
- Key-value modifier: `.user-card--size-large`, `.user-card__status--state-active`

Lowercase kebab-case for words inside a block/element/modifier.
**Double underscore** separates block from element.
**Double hyphen** separates the block (or block__element) from its modifier.
**Single hyphen** inside multi-word names.

Forbidden variants in this project (other BEM-ish styles exist; pick one and stay there):
- `block_element` (single underscore)
- `block_modifier_value` (Yandex-flat style)
- `blockElement` (camelCase)
- `block-element` (no separator distinction → can't tell element from modifier)

## What is a block vs. an element vs. a modifier

- A block is anything that could conceivably appear elsewhere in the app.
  `header`, `footer`, `button`, `modal`, `user-card`, `employee-row`.
- An element is a structural piece of one specific block:
  `user-card__avatar` is meaningful only inside `.user-card`.
- A modifier expresses a runtime condition: state (`--loading`, `--error`,
  `--disabled`), variant (`--primary`, `--secondary`), size (`--size-large`).

If you find yourself naming `card-avatar` (block-name as prefix), it's an
element of `card` → write `card__avatar`. If you find yourself nesting
modifiers (`card--primary--large`), use key-value:
`card--variant-primary card--size-large`.

## Hard rules

1. **Class selectors only.** No tag selectors, no ID selectors, no
   descendant selectors, no `> child` selectors. CSS rules are flat,
   one class per rule (with rare exceptions for modifier states like
   `.button:hover` and `.button:focus-visible`).

2. **Blocks have no external margins.** A block knows nothing about its
   surroundings, so it cannot set its own outer spacing. The parent layout
   (which is itself a block) sets gaps between children via grid/flex gap
   or via its own padding. Forbidden: `.user-card { margin-bottom: 16px }`.

3. **One block per file.** A block lives in its own directory with at
   minimum a `.tsx` (React component) and a `.css` (BEM-named styles).

4. **No nested selectors.** Whether the CSS file is plain CSS, SCSS, or
   CSS-in-something — flat is the rule. `.user-card .user-card__avatar`
   is forbidden; write `.user-card__avatar` directly.

5. **No global resets inside blocks.** A reset / base / token layer lives
   in `src/shared/ui/base/` (see file layout below). Blocks never style
   global selectors.

6. **Modifiers compose, they don't replace.** Set the block class AND
   the modifier class on the same element: `class="user-card user-card--featured"`,
   not just `class="user-card--featured"`. Modifier styles only override.

## File layout

```
frontend/src/
├── app/
├── pages/
├── features/
│   └── <feature-name>/
│       ├── <feature-name>.tsx
│       ├── <feature-name>.css           # BEM-named styles for this block
│       └── components/
│           └── <sub-block>/
│               ├── <sub-block>.tsx
│               └── <sub-block>.css
├── entities/
│   └── <entity-name>/
│       ├── <entity-name>.tsx
│       └── <entity-name>.css
└── shared/
    ├── ui/
    │   ├── base/                         # design tokens, resets
    │   │   ├── reset.css
    │   │   └── tokens.css                # CSS custom properties
    │   ├── button/
    │   │   ├── button.tsx
    │   │   └── button.css
    │   ├── modal/
    │   ├── input/
    │   └── ...
    ├── auth/                             # AuthProvider (Clerk wrapper + token bridge)
    ├── api/
    ├── lib/
    └── config/
```

Each directory == one block. The directory name matches the block class
name (kebab-case). Element/modifier classes derive from the directory's
block name.

## Plain CSS, not CSS Modules / Tailwind / styled-components

BEM's point: the global namespace IS the contract — `.user-card__name` reads
identically everywhere. CSS Modules scope-mangle names (breaks the contract);
Tailwind bypasses it; styled-components encodes styles in JS. Pick none.

Use plain `.css` files, imported at the top of the component:

```tsx
// src/shared/ui/user-card/user-card.tsx
import "./user-card.css";

interface Props {
  name: string;
  role: string;
  featured?: boolean;
  avatarUrl?: string;
}

export function UserCard({ name, role, featured, avatarUrl }: Props) {
  const cardClass = featured ? "user-card user-card--featured" : "user-card";
  return (
    <article className={cardClass}>
      {avatarUrl && (
        <img className="user-card__avatar user-card__avatar--rounded"
             src={avatarUrl} alt="" />
      )}
      <h3 className="user-card__name">{name}</h3>
      <p className="user-card__role">{role}</p>
    </article>
  );
}
```

```css
/* src/shared/ui/user-card/user-card.css */
.user-card {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: var(--space-4);
    background: var(--surface-default);
    border-radius: var(--radius-md);
}

.user-card--featured {
    border: 2px solid var(--accent-primary);
}

.user-card__avatar {
    width: 64px;
    height: 64px;
    object-fit: cover;
}

.user-card__avatar--rounded {
    border-radius: 50%;
}

.user-card__name {
    margin: 0;
    font-size: var(--text-lg);
    font-weight: 600;
}

.user-card__role {
    margin: 0;
    color: var(--text-muted);
    font-size: var(--text-sm);
}
```

Note: no margins on the block, no nested selectors, only class selectors,
modifiers are separate classes that compose with the block class.

## Conditional className helper

Building `className` strings by hand gets noisy with multiple modifiers.
Use a small helper (no dep needed) or `clsx` if it's already in the project:

```ts
// src/shared/lib/cn.ts — tiny conditional className builder
export function cn(...parts: Array<string | false | null | undefined>): string {
  return parts.filter(Boolean).join(" ");
}
```

```tsx
import { cn } from "@/shared/lib/cn";

<article className={cn(
  "user-card",
  featured && "user-card--featured",
  size && `user-card--size-${size}`,
)}>
```

Avoid `classnames` library / `clsx` unless already needed — `cn` above is six lines.

## When BEM does not fit

- Third-party component libraries (Clerk widgets, date pickers) — use their
  classes as-is, wrap them in your own block if you need BEM-named outer
  styles.
- Generated content (Markdown render, OpenAPI tables) — apply BEM via the
  wrapper, accept the inner HTML's defaults.

Everything else in the app — every block written by the team — follows BEM.
