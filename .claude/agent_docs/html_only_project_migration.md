# HTML-Only Project Migration

Use this when the source project is standalone HTML/CSS/JS and the user needs
usage logging, analytics, action review, persistence, auth, or multi-user
visibility.

## Required Approach

1. Move the UI into `frontend/` as React + TypeScript + Vite.
2. Keep styles as plain CSS with BEM and the installed design tokens.
3. Add the fixed backend stack under `backend/`: Java 21, Spring Boot 3.x,
   Maven multi-module, PostgreSQL, Liquibase, contract-first OpenAPI.
4. If `backend/event-logging-to-db-feature/` is present, persist user action
   events in PostgreSQL `usage_events`; do not rely on browser-only console logs
   or `localStorage` analytics.
5. With that MVP module present, explicit actions normally use
   `POST /api/v1/usage-events`. Set `app.usage-logging.enabled: false` to disable
   AOP/service auto-logging and prevent duplicate rows; the explicit endpoint
   still writes through the usage event sink.
6. If the module is absent (including after engineering handoff), do not
   recreate it implicitly. Capture the analytics requirements and choose a
   production sink through an explicit engineering decision before adding
   instrumentation.
7. Package the Vite build into the Spring Boot jar so Replit exposes one public
   backend port serving both `/api/*` and the SPA.

## Forbidden Fallbacks

- Static-only output when centralized usage review is required.
- Node, Express, Python, Flask, or Django backends.
- Local-only logging, console-only analytics, or browser-only event storage.
- A second project layout that differs from `backend/` + `frontend/`.
