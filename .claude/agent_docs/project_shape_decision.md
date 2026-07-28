# Project Shape Decision

Use this before generation or before deciding whether a task is frontend-only.

## Existing Generated Project

If `backend/` already exists, do not remove or bypass it unless the user
explicitly asks for a migration. A frontend-only task means: modify only
`frontend/` files and keep the existing backend contract intact.

## New Project

Default to the generated full-stack layout: `frontend/` React + TypeScript +
Vite and `backend/` Java 21 + Spring Boot + Maven + PostgreSQL.

Frontend-only is allowed only when all conditions are true:

1. The user explicitly asks for a static/front-end-only page, mockup, prototype,
   calculator, visual demo, or no-backend app.
2. There is no authentication or user identity requirement.
3. There is no persistence, uploads, audit trail, usage review, analytics, or
   user action logging requirement.
4. There is no backend API, scheduled job, external integration, secret, or
   server-side validation requirement.
5. There is no multi-user visibility or shared state requirement.

If any condition is false, use the full-stack layout.

## Backend Triggers

Use full-stack immediately when the prompt mentions any of these:

- login, SSO, Clerk, auth, user, role, permission, approval, admin;
- save, history, database, export from stored data, upload, file processing;
- usage logging, analytics, dashboard, review user actions, click tracking;
- API, webhook, integration, secret key, token, cron, scheduled sync;
- multiple users, shared workspace, manager view, audit, compliance.

## HTML-Only Source

Standalone HTML/CSS/JS is only an input format. If backend triggers exist,
migrate it using `html_only_project_migration.md` instead of keeping it
static-only.
