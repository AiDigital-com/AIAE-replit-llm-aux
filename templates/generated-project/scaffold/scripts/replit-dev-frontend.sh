#!/usr/bin/env bash
#
# replit-dev-frontend.sh — frontend task of the Replit "Run" workflow.
#
# Independent of the backend task: no Maven here. The vite dev server binds
# 5173 and proxies /api to the backend on 5000.

set -euo pipefail

cd "$(dirname "$0")/.."

cd frontend

if [ -f package-lock.json ]; then
  npm ci
else
  npm install
fi

npm run generate:api

exec npm run dev -- --host 0.0.0.0 --port 5173
