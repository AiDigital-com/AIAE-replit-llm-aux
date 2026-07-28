---
description: Frontend architecture, API, auth, and styling rules.
paths:
  - "frontend/src/**/*.ts"
  - "frontend/src/**/*.tsx"
  - "frontend/src/**/*.css"
  - "frontend/vite.config.ts"
  - "frontend/package.json"
---

# Frontend Rules

- Client-side routing uses React Router `BrowserRouter` in
  `frontend/src/app/AppRoot.tsx`. Do not use `HashRouter`, manual
  `window.history` routing, or route ownership in `main.tsx`.
- Deployment must preserve deep links through `SpaFallbackController` for the
  Spring-served SPA and `try_files ... /index.html` for the nginx frontend.

- Use React + TypeScript + Vite.
- Use `openapi-fetch` through `frontend/src/shared/api/client.ts`; raw `fetch`, `axios`, and hardcoded backend URLs are forbidden under `frontend/src`.
- Generated OpenAPI types are not edited manually.
- Use TanStack Query for backend server state.
- Each server resource has one canonical query-key owner. Components reuse that query or its cached data instead of issuing equivalent requests under different keys.
- Cache data according to its lifecycle. Data that is stable for the authenticated session stays cached until account/session change or an explicit successful update; clear user-scoped cache on sign-out and account switch.
- Fetch only when the data is required. Disable queries until their inputs and owning UI surface are active; do not preload hidden tabs, closed dialogs, or unavailable permission branches without a measured reason.
- Mutations update the canonical cache directly when the response is authoritative; otherwise invalidate only affected queries. Broad cache invalidation and refetching unrelated resources are forbidden.
- Polling, eager prefetching, and duplicate detail/list requests require a documented freshness or latency reason. Request count is part of frontend correctness.
- Pass TanStack Query's `AbortSignal` through the generated `openapi-fetch`
  boundary for cancellable searches/navigation; an obsolete response must not
  replace newer state.
- User-driven search is debounced. Polling stops on terminal state,
  hidden/unmounted ownership, authorization loss, or bounded error exhaustion.
- Multi-item actions use one bulk mutation and one narrow cache update or
  invalidation, not sequential per-item requests/refetches.
- Paginate or incrementally load growing collections; do not fetch complete
  datasets only to filter/sort them in the browser.
- Lazy-load heavy editor, chart, admin, and non-entry routes/features. Compare
  supported Vite production-build output before/after; do not add blanket React
  memoization without profiler evidence.
- Clerk owns frontend auth; protected calls send Bearer JWT through the shared API client.
- Frontend env vars must not contain secrets.
- Preserve the ports, allowed hosts, runtime alias, and proxy behavior defined by
  the current repository; do not replace them with remembered defaults.
- Preserve the product's established navigation model. For a new project with
  no explicit navigation decision, follow the installed design guidance.
- Use plain CSS with BEM naming. Do not introduce CSS Modules, Tailwind, styled-components, Emotion, or CSS-in-JS.
- Use semantic CSS variables/tokens for colors and spacing instead of new hardcoded color literals.
- Runtime CSS under `frontend/src/**/*.css` uses `rem` units and semantic
  tokens; raw `px` units and hard-coded hex colors are forbidden.
- Use flexbox for one-dimensional layout and CSS grid only for
  two-dimensional/table-like layout such as data rows and multi-column forms.
  Four-column forms use `repeat(4, minmax(0, 1fr))` with responsive collapse.
- Long user/API text must not break layout. Shrinkable flex/grid children set
  `min-width: 0` or `min-inline-size: 0`; text containers set
  `overflow-wrap: anywhere`; controls and media cap at `max-inline-size: 100%`.
- Buttons are inline-flex centered and must tolerate wrapped labels.
- Generated forms validate OpenAPI-required fields before submit and expose
  accessible errors through `required`/`aria-required`, `aria-invalid`,
  `aria-describedby`, and/or `role="alert"`.
- Interfaces and types belong in a `model/` directory, not in component files. Extract any shared or domain `interface`/`type` into a dedicated `.ts` file under `model/` next to the feature; component `.tsx` files import types, they do not declare exported interfaces.
- Static constants belong in a `constants/` directory, not in component files. Move any runtime-independent constant (magic values, enum-like mappings, column maps, storage keys, config keys) into a `.ts` file under `constants/`; components import constants, they do not inline them.
- Order imports in three groups separated by blank lines: (1) React, (2) third-party libraries, (3) project imports. The scaffold's local ESLint rule `project-rules/import-section-order` enforces this and fails the build on violations.
- Component `.tsx` files must not declare inline `interface` or `type` aliases, and must not keep top-level static `const` declarations. Move types to `model/*.ts`, static values to `constants/*.ts`, and use function declarations for components.
