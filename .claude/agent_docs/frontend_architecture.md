# Frontend Architecture

`frontend/src/app/AppRoot.tsx` owns React Router and must mount
`BrowserRouter`. `main.tsx` only mounts `AppRoot`. Browser history URLs are the
public contract, so both Spring (`SpaFallbackController`) and nginx
(`try_files ... /index.html`) must serve the SPA entry point for deep links.
`HashRouter` and manual `window.history` routing are not supported.

## Stack

- React + TypeScript.
- Vite for development and production build.
- Vitest + Testing Library for behavior tests.
- TanStack Query for server state.
- Clerk React SDK for authentication.
- `openapi-typescript` + `openapi-fetch` for typed backend API access.
- Plain CSS with BEM naming for styling.

## Folder layout

Use this layout for new frontend code:

```text
frontend/src/app
frontend/src/pages
frontend/src/features
frontend/src/entities
frontend/src/shared/api
frontend/src/shared/auth
frontend/src/shared/ui
frontend/src/shared/lib
frontend/src/shared/config
frontend/src/test
```

Feature code belongs under `frontend/src/features/<feature-name>/` unless it is genuinely shared.
Shared primitives belong under `frontend/src/shared/`.
Do not create unrelated parallel structures for the same concern.

## Vite rules

- Preserve the dev/preview and backend ports configured by the repository. Keep
  them distinct and do not replace them with remembered defaults.
- `vite.config.ts` must keep explicit `server.allowedHosts` and `preview.allowedHosts` for proxied preview hosts.
- Runtime alias `@` must be configured in Vite, not only in `tsconfig.json`.
- API proxy target is configurable through environment variables, not hardcoded per component.
- The app UI must never render a placeholder telling the user to switch preview ports. The first screen is the real product UI.

## OpenAPI boundary

- OpenAPI YAML is the backend/frontend contract.
- Frontend generated types live in `frontend/src/shared/api/generated/schema.d.ts` and are not edited manually.
- `frontend/src/shared/api/client.ts` owns the `openapi-fetch` client and auth-aware request handling.
- Components and feature APIs must use the typed client. Raw `fetch`, `axios`, `XMLHttpRequest`, and hardcoded backend URLs are forbidden under `frontend/src`.
- `VITE_API_BASE_URL` and `VITE_API_CONTEXT_PATH` must not include `/api/v1` when OpenAPI path keys already include `/api/v1`.
- Run `npm run generate:api` before typecheck/build when the OpenAPI contract changes.

## Server state and async UI

- Use TanStack Query for backend reads and writes.
- Do not store server state in ad-hoc global state.
- Every server-backed UI surface must handle loading, empty, error, and success states.
- Mutations must invalidate or update the relevant queries explicitly.

### Request-efficiency model

Treat network requests as observable application behavior, not as an incidental implementation detail.

- Define canonical query keys next to the feature API/query options that own the resource. Consumers must reuse them rather than creating component-local aliases for the same data.
- Let one query own each server resource. Derive filtered, grouped, or projected views with `select`, memoization, or cached parent data instead of fetching the same resource again.
- Choose `staleTime` and `gcTime` from the resource lifecycle, not from a universal default. Session-stable identity, access, and user-context data may remain fresh for the authenticated session and must be cleared when the user signs out or switches account.
- Use `enabled` for dependent queries and inactive UI. Closed dialogs, unselected tabs, unresolved identifiers, and permission-inaccessible branches must not request data by default.
- When a mutation returns the complete authoritative resource, write it into the canonical cache with `setQueryData`. Invalidate only when the response cannot safely update all affected cached views.
- Avoid invalidating broad key prefixes when the affected keys are known. Never refetch unrelated profile, access, reference, list, or detail data after a local mutation.
- Reuse list data for previews when it satisfies the view. Fetch detail data only when the detail contract is actually required.
- Poll only for a real server-side lifecycle that cannot push updates. Stop polling on terminal state, hidden/unmounted ownership, missing authorization, or error policy exhaustion.
- Pass TanStack Query's `signal` through the typed `openapi-fetch` request
  options. Searches and navigation-owned requests must be cancellable so
  obsolete work and stale responses do not outlive their owner.
- Debounce user-driven search, and prefer one bulk mutation plus one narrow
  cache update/invalidation over sequential per-item requests.
- Paginate or incrementally load growing collections; do not fetch complete
  datasets only to filter or sort in the browser.
- Prefetch only an evidenced next interaction. It must not turn every visible row, tab, or navigation item into an automatic request.
- Do not add a second client-side cache around TanStack Query. Browser HTTP caching may complement it, but must not create a competing source of truth.

For affected flows, validate request counts in browser tooling or automated tests. Check initial load, rerender, navigation away/back, opening and closing overlays, repeated actions, successful mutation, sign-out, and account switch. Equivalent data must not be requested again while its canonical cache entry is valid.

## Bundle and route loading

- Route/feature split heavy editors, charts, admin surfaces, and other code not
  required for the first usable screen with React lazy loading and a deliberate
  loading boundary.
- Use the existing Vite production build as the baseline and compare emitted
  asset/chunk sizes after the change. Do not add a bundle-analysis dependency
  unless the repository already supports it or the user approves it.
- Do not add blanket `memo`, `useMemo`, or `useCallback`; use profiler evidence
  and identify the expensive work or unstable dependency first.

## Auth

- Clerk is the frontend auth provider.
- Protected backend calls send `Authorization: Bearer <jwt>` through the shared API client.
- Bootstrap the current application user through the typed auth endpoint defined
  by the project's OpenAPI contract.
- `401` routes the user back through the auth flow.
- `403` renders an access-denied or locked-state UI, not a generic crash.
- Frontend code never accesses service-account keys, database credentials, or backend secrets.

## Navigation and layout

- Preserve the product's established navigation model. For a new project with
  no documented navigation decision, use a compact header-first layout.
- Do not introduce or remove a permanent left side menu, rail, or sidebar as
  part of unrelated work.
- Prefer page tabs, filter bars, segmented controls, and contextual toolbars.
- Operational screens should be dense, scannable, and work-focused rather than marketing-style landing pages.
- Use flexbox for one-dimensional rows/stacks/toolbars. Use CSS grid for
  two-dimensional/table-like layouts such as data rows and multi-column forms;
  four-column forms use `repeat(4, minmax(0, 1fr))` and responsive collapse.
- Runtime CSS uses semantic tokens and `rem`; raw `px` and hard-coded hex colors
  are forbidden under `frontend/src/**/*.css`.
- Shrinkable content containers set `min-width: 0` or `min-inline-size: 0`, text
  uses `overflow-wrap: anywhere`, and buttons stay inline-flex centered so long
  labels and user/API strings do not break mobile or desktop layout.

## Forms

- Generated forms mirror OpenAPI `required` and validation constraints before
  submit.
- Required controls expose `required` or `aria-required`; invalid controls use
  `aria-invalid` and link to an announced error with `aria-describedby` and/or
  `role="alert"`.
