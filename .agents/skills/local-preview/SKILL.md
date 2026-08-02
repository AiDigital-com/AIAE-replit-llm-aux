---
name: local-preview
description: Make the current product locally demonstrable and start it when the user says they want to see, preview, demo, or run what has been built. Creates safe local-only fixtures when needed and reports exact credential setup without requesting secrets in chat.
---

# Local Preview

Use when the user says “I want to see what we have,” “show me,” “run it,”
“start a demo,” or equivalent. The outcome is a running, verified local preview
with a URL the user can open—not merely a list of commands.

## Decision ownership

Treat the user as the business owner. Do not ask them to choose a server,
fixture framework, Docker strategy, database seed mechanism, or auth workaround.
Discover the repository and choose the safest existing local-development path.
Ask only for business data that must appear in the demo or access that only the
user can grant.

## 1. Discover the runnable shape

Read the repository entry point, `docs/architecture-overview.md` when present,
the local-run section of README, `.env.example`, and existing launch scripts.
Determine:

- frontend-only or full stack;
- supported local launcher and public URL;
- health/readiness endpoints;
- required credentials and external services;
- whether the main user journey needs data that is currently absent.

Prefer the repository's existing launcher. In this generated full-stack project,
use Docker Compose:

```bash
docker compose --profile local up --build -d
```

Do not replace a working launcher or introduce a second local runtime path.

## 2. Keep a meaningful demo fixture available

For every user-visible flow touched by the task, ensure a first-time local run
has enough deterministic data to demonstrate the accepted behavior.

Add a fixture only when the flow otherwise cannot be meaningfully viewed.
Reuse the repository's existing seed, migration, fixture, or mock-adapter
mechanism. If none exists, create `scripts/local-preview-fixtures.sh` as an
idempotent local-only hook and document what it creates.

Fixture rules:

- deterministic and safe to run repeatedly;
- explicitly local/test scoped and impossible to enable accidentally in
  production;
- no customer data, production exports, tokens, or embedded secrets;
- stable IDs/names where the UI or tests depend on them;
- exercise the real application boundary where practical;
- any mock integration is clearly labeled in the UI/README and does not
  silently replace production behavior.

Implementation work is incomplete when its primary visible flow cannot be
demonstrated because obvious fixture data was omitted.

## 3. Handle credentials without collecting secrets

Inspect consumed configuration and `.env.example`. If a credential is missing:

1. stop before starting a predictably broken preview;
2. name the exact variable;
3. tell the user where to obtain it;
4. tell them to place it in local `.env`, Replit Secrets, or the target secret
   manager as appropriate;
5. never ask them to paste the value into chat and never write it into a tracked
   file.

For the default Clerk local flow, real interactive sign-in requires
`CLERK_PUBLISHABLE_KEY` and the configured `AUTH_AUTHORIZED_PARTIES` origins in
the gitignored root `.env`, with the Google connection already enabled in the
Clerk dashboard. `CLERK_SECRET_KEY` is needed only when the agent must run
`scripts/configure-clerk-development.sh` to change the Clerk instance; it is
not a prerequisite for normal application sign-in. Confirm required variables
are non-empty without printing their values.

## 4. Start and verify

Start the supported local stack and keep it running. For the default full stack:

1. run `docker compose --profile local config`;
2. run `docker compose --profile local up --build -d`;
3. wait for `http://localhost:8080/<context-path>/actuator/health`;
4. run `scripts/local-preview-fixtures.sh` if the project has that hook;
5. verify the frontend returns HTML at `http://localhost:5173/`;
6. inspect container status and relevant error logs.

Do not claim the preview works from process startup alone. Verify the health
endpoint and the main visible route. If Docker is unavailable, use an existing
documented non-Docker launcher; do not invent one in the middle of the preview.

## 5. Report for a non-technical user

Return only the useful handoff:

- **Open:** the exact local URL;
- **What is ready to try:** two or three business actions;
- **Demo data:** what fixture records exist, or “none required”;
- **Sign-in/setup:** only remaining human action, with the exact safe settings
  location;
- **Stop:** `docker compose --profile local down`;
- any unverified limitation stated plainly.

Leave the preview running unless the user asks to stop it. Do not stage, commit,
push, or expose a local service publicly without explicit authorization.
