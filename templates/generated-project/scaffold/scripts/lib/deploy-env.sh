#!/usr/bin/env bash
#
# Published-app environment overrides: maps PRD_<NAME> onto <NAME>.
#
# Unlike replit-env.sh — which the dev workflows source too — this file is
# sourced ONLY by replit-build.sh and replit-run.sh, and .replit invokes those
# two exclusively from [deployment]. So the base variables hold the values the
# Replit workspace uses (dev Clerk instance, preview hostnames), and the
# published app gets the PRD_* twins on top.
#
# Source order matters: deploy-env.sh runs BEFORE replit-env.sh so that the
# normalization there (e.g. VITE_CLERK_PUBLISHABLE_KEY defaulting from
# CLERK_PUBLISHABLE_KEY) sees the already-swapped production values. Swapping
# afterwards would leave the VITE_* twin holding the dev key, and vite.config.ts
# prefers VITE_CLERK_PUBLISHABLE_KEY over CLERK_PUBLISHABLE_KEY.
#
# To give the published app its own value for <NAME>, set PRD_<NAME> in Replit
# Configurations (or Secrets, for CLERK_SECRET_KEY). Leave PRD_<NAME> unset to
# share the base value across both environments.

set -euo pipefail

DEPLOY_OVERRIDABLE_VARS=(
  CLERK_PUBLISHABLE_KEY
  CLERK_SECRET_KEY
  AUTH_AUTHORIZED_PARTIES
  APP_SECURITY_CSP_FRAME_ANCESTORS
)

for _deploy_var in "${DEPLOY_OVERRIDABLE_VARS[@]}"; do
  _deploy_src="PRD_${_deploy_var}"
  if [ -n "${!_deploy_src:-}" ]; then
    export "${_deploy_var}=${!_deploy_src}"
    # Names only — CLERK_SECRET_KEY must never reach the build log.
    echo "[deploy-env] ${_deploy_var} <- ${_deploy_src}"
  else
    echo "[deploy-env] WARNING: ${_deploy_src} is unset;" \
      "the published app will use the base ${_deploy_var}" >&2
  fi
done

unset _deploy_var _deploy_src
