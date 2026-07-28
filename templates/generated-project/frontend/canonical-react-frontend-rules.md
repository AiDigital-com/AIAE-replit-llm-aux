# Canonical React Frontend Rules

Single source of truth for React frontend. Bulletproof-React-inspired,
adapted for MVP→handoff.

## Stack

- React + TypeScript (strict).
- Vite (other frameworks only on explicit user request).
- Elevate visual system via
  `templates/generated-project/frontend/elevate-design-guidelines.md`.

## Bootstrap rule — copy the scaffold, do NOT regenerate

`frontend/vite.config.ts`, `package.json`, `tsconfig.json`, `index.html`,
`nginx.conf.template`, `Dockerfile` MUST be copied verbatim from
`templates/generated-project/scaffold/frontend/`.

**Forbidden:** `npm create vite@latest`, `npx create-vite`, any other
Vite/CRA scaffolder. Generators strip Replit-specific settings; regenerating
re-hits these three bugs:

1. **`allowedHosts` missing or wrong** → Replit preview returns
   `Blocked request. This host ("xxx.picard.replit.dev") is not allowed.`
   Vite 5+ requires explicit allow-list behind a proxy with unfamiliar Host.
   - REQUIRED: array including `.replit.dev`, `.repl.co`, `.kirk.replit.dev`,
     `localhost`, `127.0.0.1` (leading dot = subdomain wildcard).
   - FORBIDDEN (silently broken): `allowedHosts: 'all'`, `allowedHosts: '*'`
     (both are literal hostnames, not wildcards — block every request).
     `allowedHosts: true` works but disables security; use the explicit array.
   - Apply to BOTH `server` AND `preview` blocks.

2. **Port set to 5000** → collides with Spring backend. Vite stays on `5173`;
   backend owns `5000`. Reversing breaks Replit Deployment (serves published
   port from Spring's built static files).
   The app UI must never render a "React dev server is running on port 5173"
   placeholder, "Switch the preview pane", or "Open on port 5173" screen.
   Port instructions belong in README only. First screen is always the actual
   product UI.

3. **Proxy `target` hardcoded `http://localhost:8080`** → wrong port in
   Replit workspace (backend on `5000`). Read from `BACKEND_DEV_PORT`,
   default `5000`. See scaffold for canonical proxy block.

4. **`@/*` works in `tsc` but fails in Vite** → `tsconfig.json` path aliases
   are not runtime aliases. `vite.config.ts` MUST include
   `resolve.alias["@"] = fileURLToPath(new URL("./src", import.meta.url))`.

5. **`openapi-fetch` `baseUrl` / `BASE_URL` set to `/api/v1`** → calls become
   `/api/v1/api/v1/...` because OpenAPI path keys already include the prefix.
   Default `apiBaseUrl` is empty; only set a host or servlet context prefix.

6. **Wrong endpoint path/method from UI (`PATCH` vs `PUT`,
   `/usage/summary` vs `/admin/usage`)** → frontend bypassed the typed
   OpenAPI boundary or used stale generated types. Use only
   `shared/api/client.ts` (`openapi-fetch`) for backend calls; raw
   `fetch`/`axios`/`XMLHttpRequest` is forbidden under `frontend/src`.
   Run `npm run generate:api` before Vite and before typecheck/build.

Regeneration (major Vite upgrade): diff against scaffold MUST preserve all six.

- `openapi-typescript` (types) + `openapi-fetch` (HTTP client).
- TanStack Query for server state.
- Clerk React SDK when SSO is enabled (see
  `templates/generated-project/auth/google-sso-clerk-blueprint.md`).
- Vitest + Testing Library for frontend behavior tests.
- **Plain CSS files with BEM naming** for styling — NOT CSS Modules,
  Tailwind, styled-components, Emotion, or CSS-in-JS. See
  `templates/generated-project/frontend/bem-naming-rules.md`.
- Runtime CSS uses semantic CSS variables and `rem` units. Raw `px` units are
  forbidden in `frontend/src/**/*.css`; convert design pixel specs into rem
  tokens in `src/shared/ui/base/tokens.css`.
- **No left side menu**. Use a top app header, page tabs, filter bars,
  segmented controls, and contextual toolbars. Do not generate `Sidebar`,
  `SideNav`, `LeftNav`, drawer-as-navigation, or a permanent left rail unless
  the user explicitly overrides this template rule.

## Folder layout

```
src/app          src/pages        src/features
src/entities     src/shared/api   src/shared/auth
src/shared/ui    src/shared/lib   src/shared/config
```

Each feature/block directory may contain a `model/` subdirectory for TypeScript
interfaces and types, and a `constants/` subdirectory for static constants (see
“Code organization” below).

## Code organization

- **Interfaces and types live in `model/`.** Any `interface` or `type` alias
  that is shared across two or more files, or that represents a domain/model
  contract, MUST be extracted from its component file into a dedicated `.ts`
  file under a `model/` directory next to the feature (e.g.
  `src/features/<block>/model/types.ts`). Component `.tsx` files must not
  declare exported interfaces — they import them from `model/`.
- **Static constants live in `constants/`.** Any constant whose value does not
  depend on runtime input (magic strings/numbers, enum-like mappings, config
  keys, column maps, storage keys) MUST be moved out of component files into a
  dedicated `.ts` file under a `constants/` directory (e.g.
  `src/features/<block>/constants.ts` or `src/shared/constants/...`). Components
  import constants; they do not inline them.
- **Imports are grouped by section, enforced by ESLint.** Every source file
  orders imports in exactly three groups, separated by a blank line:
  1. **React** — `react`, `react-dom`, `react-router-dom`, hooks from React.
  2. **Third-party libraries** — everything in `node_modules` that is not React
     (e.g. `@tanstack/react-query`, `@clerk/clerk-react`, `openapi-fetch`).
  3. **Project imports** — relative or `@/*` imports from `src/`.
  The scaffold ships `eslint.config.js` plus the local
  `eslint-rules/import-section-order.mjs` rule because project imports must be
  one visual block whether they use `@/*`, `../`, `./`, or CSS side-effect
  imports. `npm run lint` fails on section-order violations.
- **Component files are lint-gated.** `src/**/*.tsx` must not declare
  `interface` or `type` aliases inline; move them to `model/*.ts`. Top-level
  `const` declarations in `.tsx` are rejected so static values move to
  `constants/*.ts`; use function declarations for components.

## Layout and CSS methodology

- Use flexbox for one-dimensional layout: stacks, rows, headers, toolbars,
  filter bars, button groups, form action rows, and compact inline metadata.
- Use CSS grid only for two-dimensional/table-like layout: data rows, card
  matrices, dashboards, and forms that visually read as columns. A four-column
  form uses `grid-template-columns: repeat(4, minmax(0, 1fr))` with explicit
  responsive breakpoints that collapse to two columns and then one column.
- Every flex/grid child that can contain user/API text must be shrink-safe:
  set `min-width: 0` or `min-inline-size: 0`; text containers set
  `overflow-wrap: anywhere`; media and form controls cap at `max-width: 100%`
  or `max-inline-size: 100%`.
- Buttons use the shared reset or matching button block rules:
  `display: inline-flex`, `align-items: center`, `justify-content: center`,
  `text-align: center`, and `max-inline-size: 100%`. Do not hardcode a fixed
  height that clips wrapped labels.
- Page and component CSS consumes spacing, radius, type, color, shadow, and
  control-size tokens. Do not write raw `px` values or hard-coded hex colors in
  runtime CSS.
- Responsive correctness is part of completion. For any changed screen, verify
  mobile and desktop widths plus a long unbroken string in titles, cells, labels,
  buttons, empty/error states, and user-entered/API-rendered content.

## Forms and validation

- OpenAPI `required`, `minLength`, `maxLength`, `format`, enum, numeric bounds,
  and nullable/optional contracts must be reflected in the form model and
  client-side validation before submit.
- Required controls render a visible label plus `required` or `aria-required`.
  Invalid controls expose `aria-invalid`, link to their error text with
  `aria-describedby`, and announce errors with `role="alert"` or an equivalent
  accessible error region.
- Trim text inputs where the backend treats blank text as missing. Prevent
  submit until required client-side validation passes; keep the submit action
  disabled while a mutation is pending.
- Server validation errors must map back to the relevant field when possible and
  to a form-level alert when not.
- Every generated form test covers at least one missing-required-field error
  and one long-string/responsive safety case for the same form surface.

## OpenAPI client generation

Source: `../backend/application/src/main/resources/api/v1/specs/openapi.yaml`
(adapt path when backend module differs and document it in README).

Required scripts in `frontend/package.json`:

```json
{
  "scripts": {
    "generate:api": "openapi-typescript ../backend/application/src/main/resources/api/v1/specs/openapi.yaml -o src/shared/api/generated/schema.d.ts",
    "check:api": "npm run generate:api && tsc --noEmit"
  }
}
```

Generated artifacts:
- `src/shared/api/generated/schema.d.ts` (never edited by hand)
- `src/shared/api/client.ts` (auth-aware fetcher built on `openapi-fetch`)

## Rules

- No handwritten DTOs duplicating OpenAPI schemas.
- No raw `fetch` calls or hardcoded backend URLs in components.
- Components do not build URLs; the typed client owns paths.
- TanStack Query for all backend reads/writes; no ad-hoc global state for server data.
- Each server resource has one canonical query-key owner. Components reuse that query or its valid cached data instead of issuing equivalent requests under different keys.
- Cache data according to its lifecycle. Data that is stable for the authenticated session stays cached until account/session change or an explicit successful update; clear user-scoped cache on sign-out and account switch.
- Fetch only when data is required. Use conditional queries for unresolved inputs, hidden tabs, closed overlays, and permission-inaccessible branches.
- Derive projections from cached source data when its contract is sufficient. Do not fetch detail data merely to reproduce fields already available in a cached list or parent resource.
- When a mutation returns authoritative data, update the canonical cache directly. Otherwise invalidate only affected keys; broad invalidation and unrelated refetching are forbidden.
- Polling and eager prefetching require a documented freshness or latency reason. Polling stops on terminal state or when its owning UI is no longer active.
- Pass TanStack Query's `signal` through the generated `openapi-fetch` request
  options. Search and navigation-owned requests must be cancellable; obsolete
  responses must not replace newer state.
- User-driven search is debounced. Multi-item actions use one bulk mutation and
  one narrow cache update/invalidation, not sequential per-item requests and
  repeated list refetches.
- Paginate or incrementally load growing collections. Do not retrieve complete
  datasets only to filter or sort them in the browser.
- Request count is part of frontend correctness. For affected flows, verify initial load, rerender, navigation away/back, repeated overlay use, successful mutation, sign-out, and account switch.
- Every async surface renders loading / empty / error / success.
- Debounce/throttle hooks must be real effects. `useDebounce` uses
  `useEffect` with `setTimeout` and cleanup via `clearTimeout`; `useState`
  alone only captures the initial value and is rejected.
- Strict TypeScript; `any` only with isolation + justification.
- Semantic HTML and keyboard accessibility.
- **BEM class names** for all styles (`block`, `block__element`, `block--modifier`).
  Plain CSS only; no CSS Modules / Tailwind / styled-components.
  See `bem-naming-rules.md` for the full convention and examples.
- Follow Elevate tokens: primary `239 100% 43%`, secondary surface
  `240 78% 98%`, accent surface `237 76% 94%`, compact Inter typography,
  `0.75rem` card radius, `0.625rem` controls, one primary CTA per view, status
  colors only for state.
- Never hard-code colors in component CSS. Colors live in
  `src/shared/ui/base/tokens.css`; components consume semantic variables.
- Never use raw `px` in runtime CSS. Use `rem` scale tokens and semantic
  variables.
- Navigation is top/header-first. Left side menu/sidebar patterns are forbidden.
- One block per directory: `<block-name>.tsx` + `<block-name>.css` + optional `components/`.
- Frontend never accesses the DB, service-account keys, or any secrets directly — backend APIs only.
- No secrets in frontend env vars.
- Status/reference UI is generated from the typed OpenAPI enum mapping. If an
  enum has three values, the UI cannot render a two-way toggle. Keep labels,
  badge colors, filters, and mutation controls exhaustive over the generated
  enum type so values like `ON_VACATION` cannot compile as "unknown".

## Route and bundle loading

- Lazy-load heavy editor, chart, administration, and other non-entry
  routes/features with an intentional loading boundary when they are not
  required for the first usable screen.
- Use the supported Vite production build output as the baseline and compare
  emitted chunks/assets before and after. Do not introduce a bundle-analyzer
  dependency unless the repository already supports it or the user approves it.
- Do not add blanket `memo`, `useMemo`, or `useCallback`; identify measured
  render work or an unstable dependency first.

## Auth

Follow `templates/generated-project/auth/google-sso-clerk-blueprint.md`.

UI requirements:
- Login screen renders Clerk `<SignIn/>` (Clerk SSO is the only auth mode).
- The login route is a finished product surface, not a bare provider widget:
  use the project's semantic tokens, responsive spacing, clear heading/supporting
  copy, and a deliberate auth container. Center the auth surface by default when
  that fits the approved design; preserve another documented auth composition.
- Style Clerk through its supported `appearance` API and local BEM classes. Keep
  sign-in, sign-up, verification, CAPTCHA, loading, and error states usable; do
  not replace Clerk behavior with a custom password form.
- Send `Authorization: Bearer <jwt>` to backend for protected calls.
- `/api/v1/auth/me` bootstraps user state.
- `401` → clear local auth state + redirect to login.
- `403` → access-denied UI.

## Testing

MVP is not complete with zero frontend tests when frontend logic is generated.
Use Vitest behavior tests, not snapshot-only suites.

Minimum before publish/completion:
- main route renders without crashing
- auth mode/session state is covered through the same UI path used by the app
- primary server-backed surface covers loading, error, and success states
- forms or critical user actions cover expected outcome plus one validation/error case
- every generated form covers missing required fields and one long-string layout
  case; affected screens are checked at mobile and desktop widths
- changes to query ownership, caching, lazy UI, or invalidation verify important request counts and session cache eviction

Handoff expands this into deeper role-dependent and critical-flow coverage.
