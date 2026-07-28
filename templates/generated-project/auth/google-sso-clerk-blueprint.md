# Clerk SSO Auth Blueprint

> **SSO-ONLY (authoritative).** This template supports **Clerk SSO only** — the
> mock, auto, and replit modes have been REMOVED. The backend validates Clerk
> JWTs against the Clerk JWKS (`spring-boot-starter-oauth2-resource-server`) and
> fails fast at startup when `AUTH_ISSUER_URI`/`AUTH_JWKS_URI` is unset. Do NOT
> generate mock-login, `MockJwtDecoder`, or Replit-OIDC code.

> **STACK REMINDER.** Template = Java 21 + Spring Boot 3.x. Replit-managed
> Clerk's "auto-mounted Express middleware" is Node-only — it does NOT apply.
> Spring validates Clerk JWTs via `spring-boot-starter-oauth2-resource-server`
> + Clerk JWKS. Re-read `custom_instruction/instructions.md` STACK LOCK if
> tempted toward Flask/Express.

Single source of truth for auth. Other files reference this; never restate.

## Two ways to wire Clerk on Replit

| | Replit-managed Clerk Auth | Standalone Clerk Dashboard |
|---|---|---|
| Tenant | Auto-provisioned by Replit per app (dev + prod separate). | Created manually in Clerk Dashboard. |
| Keys | `CLERK_PUBLISHABLE_KEY` + `CLERK_SECRET_KEY` **auto-injected** as Replit Secrets; dev↔prod switched automatically on Deploy. | Copied manually from the Dashboard into Replit Secrets / `.env`. |
| Google social login | Toggle in Replit's **Auth pane**. | Configured in Clerk Dashboard. |
| Manual Secret editing | **Forbidden** — breaks the integration. | Allowed. |
| Portability to local docker-compose | Not portable (tied to the workspace). | Fully portable. |
| Frontend SDK | `@clerk/clerk-react` via `AuthProvider` in `app/AppRoot.tsx` (not raw `<ClerkProvider>` in `main.tsx`). | Same pattern; set `VITE_CLERK_PUBLISHABLE_KEY` in `.env` for local-dev. |
| Backend (Spring Boot) | Spring verifies JWTs via `oauth2-resource-server` + Clerk JWKS. | Same Spring path. |

**Choose managed** when the app ships primarily on Replit and you don't need the
same Clerk tenant in local docker-compose. **Choose standalone** when the app
must run on Replit AND engineering's local docker-compose with the same
identities, or compliance requires owning the tenant. Managed-Clerk credentials
do not export to docker-compose — for local parity, provision a standalone
tenant and set `AUTH_ISSUER_URI` / `CLERK_*` in `.env`.

## Preferred architecture

`Google → Clerk → application`. Clerk issues the JWT; Spring verifies it as an
OAuth2 Resource Server (signature against Clerk JWKS, plus `iss` / `aud` / `exp`
/ `nbf`). Direct Google OIDC without Clerk only when project standards require it.

## Backend contract

Dependencies: `spring-boot-starter-security`, `spring-boot-starter-oauth2-resource-server`.

`SecurityConfig` provides a single `@Bean JwtDecoder` (a `NimbusJwtDecoder` built
from `app.auth.sso.jwk-set-uri`, or discovered from `issuer-uri`) and a stateless
filter chain. It **fails fast** at startup if neither issuer nor JWKS is set —
there is no fallback. Never set `spring.security.oauth2.resourceserver.jwt.*` in
YAML (auto-config crashes on an empty issuer); the bean owns the decoder.

Protected endpoints require a Bearer JWT. The backend validates:
- signature against the Clerk JWKS endpoint,
- `iss`, `aud` (when configured), `exp`, and `nbf`.

Issuer and JWKS are derived from `CLERK_PUBLISHABLE_KEY` by
`ClerkPublishableKeyDecoder`. Set `AUTH_ISSUER_URI` / `AUTH_JWKS_URI` only to
override a non-Clerk or manually-managed tenant; leave them blank otherwise.

### Principal-key contract (REQUIRED)

The canonical principal id is the Clerk **`user_id`** claim — the stable backend
and usage-logging identity. It is bound to `Authentication#getName()` via
`JwtAuthenticationConverter#principalClaimName="user_id"`.

- `user_id` (== `sub` in the `aidigital-api` template) is the stable identity.
  `ClerkJwtClaimsValidator` requires `sub` and `user_id` to be present and equal.
- `email` is **not** the principal. It is stored separately (lowercased, trimmed)
  for display and for company-domain authorization.
- When `backend/event-logging-to-db-feature/` is present,
  `usage_events.user_id` receives the Clerk `user_id` and
  `usage_events.user_email` receives the normalized email. They are distinct
  columns.
- With that MVP module present, the usage aspect lifts the display name from
  the JWT `full_name` claim into
  `usage_events.attributes->>'user_name'`. If the module is absent (including
  after engineering handoff), do not recreate it from this auth guide; any
  production analytics identity mapping requires an explicit engineering
  design.

  Required Clerk JWT template (`aidigital-api`):
  ```json
  {
    "email":     "{{user.primary_email_address}}",
    "user_id":   "{{user.id}}",
    "full_name": "{{user.full_name || user.primary_email_address}}"
  }
  ```

### Authorized party (`azp`) and company-domain authorization (REQUIRED)

- **`azp`** is the trusted browser origin, never a publishable key.
  `ClerkJwtClaimsValidator` checks it against the exact origins in
  `AUTH_AUTHORIZED_PARTIES` (comma-separated, e.g.
  `http://localhost:5173,https://my-app.replit.app`). No wildcards.
  **Blank is rejected at startup** — `AUTH_AUTHORIZED_PARTIES` is required for
  any running SSO application; `azp` enforcement cannot be silently disabled.
  An untrusted `azp` → **401**.
- **Company email domain** is enforced as a *post-authentication* policy
  (`CompanyEmailDomainAuthorizationManager`), not as a JWT decoder validator:
  - missing / invalid token → **401**;
  - valid token, missing email → **403**;
  - valid token, email outside the exact `AUTH_ALLOWED_EMAIL_DOMAIN` → **403**
    (subdomains such as `team.aidigital.com` are rejected unless configured);
  - valid token, permitted email → continue.

### Authorization roles (OPT-IN — only for role-based apps)

The baseline ships **no** role tables and **no** `roles` field in
`/api/v1/auth/me`. Identity alone is the baseline contract.

Add roles only when the product requires them. In that case:
1. Configure a custom `JwtAuthenticationConverter` mapping a role source to
   `ROLE_`-prefixed authorities (do not rely on Spring's default `scope`/`scp`
   converter, which Clerk templates usually omit).
2. Load roles server-side keyed on the Clerk `user_id` and add the role table
   via Liquibase.
3. Re-add a `roles` array to the OpenAPI `UserV1` schema at that point.

Frontend role state is display-only; the backend authorizes from the validated
JWT + backend role lookup.

## Frontend contract

- The sign-in screen renders Clerk's `<SignIn/>` (the only auth mode);
  `AuthProvider` wraps the app in `<ClerkProvider>` reading the publishable key.
  On Replit-managed Clerk, `vite.config.ts` maps `CLERK_PUBLISHABLE_KEY` →
  `import.meta.env.VITE_CLERK_PUBLISHABLE_KEY`.
- Protected calls send `Authorization: Bearer <jwt>` — the token comes from Clerk
  `useAuth().getToken()`, bridged into `runtime.ts` by `AuthProvider`.
- Backend is source of truth. `GET /api/v1/auth/me` bootstraps user state.
- `401` → clear local state + redirect to sign-in. `403` → access-denied UI.
- Never store secrets in frontend env.

## Endpoints

Public: `GET /<app-context-path>/actuator/health`,
`GET /<app-context-path>/actuator/prometheus`.
Protected: `GET /api/v1/auth/me` — canonical authenticated-user payload.

## Required env placeholders

Replit Workspace + Deployment (managed Clerk — auto-injected, do not edit):
```
CLERK_PUBLISHABLE_KEY    # auto
CLERK_SECRET_KEY         # auto
```
Backend (read in `application.yml`):
```
AUTH_ALLOWED_EMAIL_DOMAIN    # REQUIRED — e.g. aidigital.com
AUTH_AUTHORIZED_PARTIES      # REQUIRED — comma-separated exact browser origins for azp
AUTH_ISSUER_URI              # optional override; derived from CLERK_PUBLISHABLE_KEY when blank
AUTH_JWKS_URI                # optional override; derived from issuer when blank
AUTH_AUDIENCE                # Clerk token audience (optional)
```
Frontend-readable (Vite exposes only `VITE_*`):
```
VITE_CLERK_PUBLISHABLE_KEY
VITE_CLERK_JWT_TEMPLATE       # set to aidigital-api
VITE_CLERK_SIGN_IN_FORCE_REDIRECT_URL
VITE_CLERK_SIGN_UP_FORCE_REDIRECT_URL
```
External provider setup (standalone Clerk Dashboard only — configured inside
Clerk, never injected into the browser): `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`.

## OpenAPI requirements

- `bearerAuth` security scheme in `components.securitySchemes`.
- `GET /api/v1/auth/me` documented with explicit `401` and `403` responses.
- Shared error schemas for auth/validation failures.

## Acceptance checks

1. Enable Clerk Auth in Replit's Auth pane (or paste standalone keys); toggle Google.
2. Set `AUTH_ISSUER_URI` (managed: from the tenant; standalone: from the Dashboard).
3. Sign in via Google through Clerk; the React SDK obtains a JWT.
4. `GET /api/v1/auth/me` → `200` with a valid token, `401` without, `403` for insufficient authority.
5. Start the backend with no issuer/JWKS → it **fails fast** (no silent unauthenticated mode).

## Replit-managed Clerk: hard rules

- **Do NOT** manually edit `CLERK_PUBLISHABLE_KEY` / `CLERK_SECRET_KEY` in Replit
  Secrets — it breaks the automatic dev↔prod switch.
- **Do NOT** configure Google OAuth in the Clerk Dashboard for the managed tenant
  — use Replit's Auth pane.
- Managed Clerk credentials don't export to local docker-compose; provision a
  standalone tenant for local parity.
