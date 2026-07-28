# HTML-Only Project Migration

Use this when the input is a standalone HTML/CSS/JS project but the user needs
usage logging, analytics, user-action review, persistence, auth, or multi-user
visibility.

## Required approach

1. Migrate the UI into `frontend/` as React + TypeScript + Vite.
2. Preserve the product behavior and copy visual intent into plain CSS with BEM.
3. Add the fixed backend under `backend/`: Java 21, Spring Boot 3.x, Maven
   multi-module, PostgreSQL, Liquibase, and contract-first OpenAPI.
4. If `backend/event-logging-to-db-feature/` is present, expose a backend
   ingestion path for explicit UI events when click/action review is required,
   normally `POST /api/v1/usage-events`.
5. With that MVP module present, persist sanitized events to PostgreSQL
   `usage_events`; never rely on browser-only console logs or `localStorage`
   analytics for centralized review.
6. With that module present, if the UI logs actions explicitly through the
   endpoint, set `app.usage-logging.enabled: false` (or default
   `USAGE_LOGGING_ENABLED=false`) so the AOP/service auto-logger does not create
   duplicate rows for the same user action. The explicit endpoint should write
   through the usage event sink directly.
7. If the module is absent (including after engineering handoff), do not
   recreate it implicitly. Capture the analytics requirements and choose a
   production sink through an explicit engineering decision before adding
   instrumentation.
8. Package the Vite build into the Spring Boot jar for Replit deployment: one
   public port, Spring Boot serves `/api/*` and the SPA.

## Forbidden fallbacks

- Single-file/static-only output when centralized usage review is needed.
- Node/Express, Python/Flask/Django, serverless-only, or static-only substitutes.
- Console-only logging, local-only logs, or browser-only analytics storage.
- A custom layout that differs from the generated `backend/` and `frontend/`
  structure.
