#!/usr/bin/env bash
#
# local-dev-frontend.sh — SPA dev server only, on a developer machine.
#
# Independent of the backend build: Maven is never invoked here. The vite dev
# server proxies /api to http://localhost:${BACKEND_DEV_PORT:-5000}, so start
# scripts/local-dev-backend.sh in another terminal (order does not matter —
# the proxy reconnects).

set -euo pipefail

cd "$(dirname "$0")/.."

if [ -f .env.local ]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi

cd frontend

if [ ! -d node_modules ]; then
  if [ -f package-lock.json ]; then
    npm ci
  else
    npm install
  fi
fi

# Regenerate the OpenAPI types from the spec before serving; the generated
# schema.d.ts is not checked in as authoritative.
npm run generate:api

exec npm run dev -- --host 0.0.0.0 --port 5173
