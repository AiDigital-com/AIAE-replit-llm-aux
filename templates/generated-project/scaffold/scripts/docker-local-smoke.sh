#!/usr/bin/env bash
#
# docker-local-smoke.sh — deterministic Docker local-profile smoke test.
# Starts PostgreSQL + backend + frontend with a synthetic Clerk publishable key
# (no live Clerk calls); verifies health, Prometheus, and the SPA response.
#
# Usage (from generated project root):
#   bash scripts/docker-local-smoke.sh
#
# Environment overrides:
#   SYNTHETIC_PK       — override the synthetic Clerk publishable key
#   APP_CONTEXT_PATH   — non-empty context path prefix (default: "")
#   COMPOSE_TIMEOUT    — seconds to wait for backend health (default: 90)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

if ! docker info >/dev/null 2>&1; then
  echo "docker-local-smoke: SKIP — Docker daemon is unavailable" >&2
  exit 0
fi

APP_CONTEXT_PATH="${APP_CONTEXT_PATH:-}"
COMPOSE_TIMEOUT="${COMPOSE_TIMEOUT:-90}"
BACKEND_PORT="8080"
FRONTEND_PORT="5173"

# Synthetic Clerk publishable key: encodes a local fake JWKS host.
# Format: pk_test_<base64(host$)> — the backend derives issuer/JWKS from this.
if [ -z "${SYNTHETIC_PK:-}" ]; then
  # Use a local JWKS stub host; AUTH_ISSUER_URI overrides so it never calls Clerk.
  SYNTHETIC_PK="pk_test_$(python3 -c "import base64; print(base64.urlsafe_b64encode(b'localhost.test\$').decode().rstrip('='))")"
fi

fail() { echo "docker-local-smoke: $*" >&2; exit 1; }

cleanup_compose() {
  docker compose --profile local down -v --remove-orphans 2>/dev/null || true
}

stop_compose() {
  echo "==> Stopping containers"
  cleanup_compose
}
trap stop_compose EXIT

echo "==> docker-local-smoke: starting"
echo "    APP_CONTEXT_PATH='${APP_CONTEXT_PATH}'"
echo "    BACKEND_PORT=${BACKEND_PORT}"
echo "==> Cleaning previous local Docker state"
cleanup_compose

# ── Build and start ───────────────────────────────────────────────────────────
if ! CLERK_PUBLISHABLE_KEY="${SYNTHETIC_PK}" \
    VITE_CLERK_PUBLISHABLE_KEY="${SYNTHETIC_PK}" \
    VITE_CLERK_JWT_TEMPLATE="aidigital-api" \
    AUTH_ALLOWED_EMAIL_DOMAIN="aidigital.com" \
    AUTH_AUTHORIZED_PARTIES="http://localhost:${FRONTEND_PORT},http://localhost:${BACKEND_PORT}" \
    AUTH_ISSUER_URI="http://localhost:${BACKEND_PORT}${APP_CONTEXT_PATH}/fake-jwks-issuer" \
    AUTH_JWKS_URI="http://localhost:${BACKEND_PORT}${APP_CONTEXT_PATH}/fake-jwks-issuer/.well-known/jwks.json" \
    APP_CONTEXT_PATH="${APP_CONTEXT_PATH}" \
    JAVA_OPTS="-Duser.timezone=UTC" \
    docker compose --profile local up --build -d; then
  echo "Docker Compose failed while starting the local stack" >&2
  docker compose --profile local ps 2>&1 || true
  docker compose --profile local logs --no-color postgres backend 2>&1 | tail -120 || true
  fail "local stack failed to start"
fi

# ── Wait for backend health ───────────────────────────────────────────────────
HEALTH_URL="http://localhost:${BACKEND_PORT}${APP_CONTEXT_PATH}/actuator/health"
echo "==> Waiting for backend health at ${HEALTH_URL}"
for i in $(seq 1 "${COMPOSE_TIMEOUT}"); do
  if curl -fsS "${HEALTH_URL}" >/dev/null 2>&1; then
    echo "    healthy after ${i}s"
    break
  fi
  if [ "${i}" -eq "${COMPOSE_TIMEOUT}" ]; then
    echo "Backend did not become healthy within ${COMPOSE_TIMEOUT}s" >&2
    docker compose logs backend 2>&1 | tail -40
    fail "backend health check timed out"
  fi
  sleep 1
done

# ── Verify Prometheus ─────────────────────────────────────────────────────────
PROMETHEUS_URL="http://localhost:${BACKEND_PORT}${APP_CONTEXT_PATH}/actuator/prometheus"
echo "==> Verifying Prometheus at ${PROMETHEUS_URL}"
prometheus_metrics="$(curl -fsS "${PROMETHEUS_URL}")" \
  || fail "Prometheus endpoint is unavailable"
grep -q 'jvm_' <<<"${prometheus_metrics}" \
  || fail "Prometheus endpoint missing jvm_* metrics"
echo "    Prometheus OK"

# ── Verify frontend SPA ───────────────────────────────────────────────────────
echo "==> Verifying frontend nginx returns SPA"
for i in $(seq 1 30); do
  if curl -fsS "http://localhost:${FRONTEND_PORT}/" | grep -qi 'html'; then
    echo "    frontend SPA OK"
    break
  fi
  if [ "${i}" -eq 30 ]; then
    fail "frontend did not return HTML after 30s"
  fi
  sleep 1
done

# ── Verify frontend /api proxy ────────────────────────────────────────────────
echo "==> Verifying /api proxy (health via frontend port)"
if curl -fsS "http://localhost:${FRONTEND_PORT}${APP_CONTEXT_PATH}/actuator/health" >/dev/null 2>&1; then
  echo "    /api proxy OK"
else
  fail "/api proxy health check failed via frontend port ${FRONTEND_PORT}"
fi

# ── Verify structured JSON application logs ───────────────────────────────────
echo "==> Verifying backend logs are structured JSON"
backend_logs="$(docker compose --profile local logs --no-log-prefix backend 2>&1 \
  || docker compose --profile local logs backend 2>&1)"
json_line="$(printf '%s\n' "${backend_logs}" \
  | sed -E 's/^[^|]*[[:space:]]\|[[:space:]]//' \
  | grep -E '^[[:space:]]*\{' \
  | grep -E '"level"|"@timestamp"' \
  | head -1 || true)"
if [ -n "${json_line}" ] && printf '%s' "${json_line}" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' 2>/dev/null; then
  echo "    JSON application logs OK"
else
  fail "backend logs must include parseable JSON lines (see logback-spring.xml)"
fi

echo "==> docker-local-smoke: passed"
