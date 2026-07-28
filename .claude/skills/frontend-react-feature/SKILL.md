---
name: frontend-react-feature
description: Build a React + TypeScript frontend feature in a generated project. Use when adding pages, features, hooks, or wiring server state. Covers typed API boundary, Clerk SSO auth UI, accessible UX states, and Replit-vs-local runtime split.
metadata:
  user-invocable: "true"
---

# Frontend React Feature

Use for any frontend change in a generated MVP project.

## Canonical references

- Frontend rules: `templates/generated-project/frontend/canonical-react-frontend-rules.md`
- Elevate design guidelines: `templates/generated-project/frontend/elevate-design-guidelines.md`
- BEM naming (CSS class convention): `templates/generated-project/frontend/bem-naming-rules.md`
- Auth blueprint: `templates/generated-project/auth/google-sso-clerk-blueprint.md`
- Project structure: `templates/generated-project/structure/near-production-project-structure.md`

## Baseline

React · TypeScript (strict) · Vite · `openapi-typescript` + `openapi-fetch` ·
TanStack Query · Clerk · Vitest.

**App shell:** `main.tsx` mounts `app/AppRoot.tsx` only. `AppRoot.tsx` owns
`BrowserRouter` + auth; `HashRouter` and manual history routing are forbidden. Product
UI lives in `features/` composed by `pages/` or `App.tsx`. Use `AppShell`,
`AppHeader`, `PageHeader`, and `shared/hooks/useDebounce.ts`.

## Core rules (delta from canonical-react-frontend-rules.md)

- No `any` unless isolated and justified.
- No raw backend calls from page components.
- No hardcoded backend URLs in components.
- No handwritten DTOs duplicating OpenAPI schemas.
- Every async surface renders loading / empty / error / success.
- Semantic HTML; keyboard-accessible controls.
- **BEM class names** for every style (`block__element--modifier`). Plain
  `.css` files, no CSS Modules / Tailwind / styled-components. One block
  per directory. Blocks have no external margins. See `bem-naming-rules.md`.
- **No left side menu / sidebar / left rail.** Use top app header, page tabs,
  filter bars, segmented controls, and contextual toolbars.
- Follow Elevate tokens: compact Inter typography, primary `239 100% 43%`,
  secondary/accent lavender surfaces, one primary CTA per view, status colors
  only for state, `0.75rem` card radius and `0.625rem` controls.
- Runtime CSS uses semantic variables and `rem` units; raw `px` and hard-coded
  hex colors are forbidden under `frontend/src/**/*.css`.
- Layout is flex-first for one-dimensional rows/stacks/toolbars. Use CSS grid
  for two-dimensional/table-like layouts, including four-column forms with
  responsive collapse (`repeat(4, minmax(0, 1fr))`).
- Long user/API text must not break UI: apply `min-width: 0`/`min-inline-size: 0`,
  `overflow-wrap: anywhere`, and `max-inline-size: 100%` where content can
  shrink or wrap. Buttons remain inline-flex centered.
- Every generated form validates OpenAPI-required fields on the client, renders
  `required`/`aria-required`, `aria-invalid`, linked accessible error text, and
  blocks submit while invalid or pending.
- Frontend never reaches the DB, service-account keys, or any secrets directly — backend APIs only.

## Auth UX

Follow the canonical blueprint. Frontend must:
- wrap authenticated routes with `ProtectedRoute` from `shared/auth/ProtectedRoute.tsx`
- show a working Clerk `<SignIn/>` sign-in screen at `/login` (Clerk SSO is the only mode)
- read the Clerk publishable key from `runtime.ts`, never `import.meta.env` directly
- attach `Authorization: Bearer <jwt>` to protected calls via `AuthProvider` token bridge
- treat backend (`/api/v1/auth/me`) as source of truth
- reuse `LoadingBlock`, `ErrorAlert`, `EmptyState` from `shared/ui/` for query states
- clear local state on `401`, render access-denied on `403`

## Runtime: Replit vs local-dev

| | Replit | Local-dev |
|---|---|---|
| Dev server | Vite on `5173` (workspace preview, mapped 1:1) | Vite on `5173` |
| Deployment | NOT Vite. Spring Boot serves the built `dist/` from its static resources; `vite.config.ts` writes the build there. | Standalone Spring or Vite preview, your call |
| API base URL | Same-origin in Deployment; `/api` proxied to `localhost:5000` in dev workspace via `vite.config.ts` | `http://localhost:8080/<context-path>` |
| Secrets | Replit Secrets pane | `.env.local` (gitignored) |

OpenAPI paths already include `/api/v1/...`. Therefore `openapi-fetch`
`baseUrl` must be empty by default or a host/context prefix only. Never set
`baseUrl`/`apiBaseUrl`/`BASE_URL`/`VITE_API_BASE_URL` to `/api/v1`; that produces
`/api/v1/api/v1/...` and breaks every API call.

`shared/config` reads runtime config from `import.meta.env` and validates it at
boot. Build-time secrets are forbidden.

The React app must never show a Replit port-switch placeholder as product UI
(`"React dev server is running on port 5173"`, `"Switch the preview pane"`,
`"Open on port 5173"`). In the workspace the developer can open preview 5173;
in deployment Spring serves the built React app from 5000. User-facing screens
must be the actual app in both cases.

## React common gotchas (real past failures)

- **Never call `navigate()` during render.** `useNavigate()` is a setter
  that triggers state update → React warning + possible infinite re-render.
  Use `<Navigate to="..." replace />` in JSX, or wrap `navigate()` in `useEffect`.
- **`401` handling lives in ONE place** — the auth-aware fetcher in
  `shared/api/client.ts`. It clears local auth + exposes a router hook
  (or context flag) the root layout renders as `<Navigate to="/login" />`.
  Pages do NOT check status codes.
- **Don't read `import.meta.env` outside `shared/config/runtime.ts`.**
  Centralising lets you validate at boot; stops typos like
  `VITE_CLERCK_PUBLISHABLE_KEY` silently rendering `undefined`.
- **TanStack Query keys are arrays, never strings.** `queryKey: ["users", id]`,
  not `queryKey: "users-" + id`. String keys break query invalidation.
- **Debounce hooks use `useEffect`, not state initializers.** Canonical
  `useDebounce<T>(value, delayMs)` has `const [debounced, setDebounced] =
  useState(value); useEffect(() => { const id = window.setTimeout(() =>
  setDebounced(value), delayMs); return () => window.clearTimeout(id); },
  [value, delayMs]); return debounced;`. A hook implemented with `useState`
  alone never updates after the initial render.
- **Vite and TypeScript aliases must both be configured.** If `tsconfig.json`
  has `@/*`, `vite.config.ts` must also define `resolve.alias["@"]`.
- **Path/method drift is a contract violation.** Calls like
  `PATCH /employees/{id}/status` when the spec says `PUT`, or
  `/usage/summary` when the spec says `/admin/usage`, must fail in typecheck.
  Use only `shared/api/client.ts` (`openapi-fetch`) under `frontend/src`.
  Raw `fetch`, `axios`, and `XMLHttpRequest` are forbidden because they bypass
  generated OpenAPI path/method types and recreate the Replit log failures.
- **Reference/status enums are exhaustive.** Labels, badge variants, filters,
  and toggle/segmented controls must cover every value in the generated OpenAPI
  enum. If the spec has `ACTIVE`, `ON_LEAVE`, `ON_VACATION`, the UI cannot be a
  two-way active/leave toggle.

## Testing requirements

MVP is not complete with zero frontend tests when frontend logic is generated.
Use Vitest behavior tests, not snapshot-only suites.

Minimum before final response/publish:
- main route renders without crashing
- auth/session state is represented through the same UI path used by the app
- primary server-backed surface covers loading, error, and success states
- forms or critical user actions cover expected outcome plus one validation/error case
- generated forms cover missing required fields and one long-string/responsive
  safety case
