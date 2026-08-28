#!/usr/bin/env bash
# Read-only AIAE deployment preflight. It prints no secret values and performs
# no repository or AWS mutation.

set -uo pipefail

WORKSPACE="."
APP_REPO=""
DEV_PROFILE=""
PROD_PROFILE=""
MODE="inspect"
ERRORS=0
WARNINGS=0

usage() {
  cat <<'EOF'
Usage: preflight.sh --workspace <directory> --app-repo <owner/repository> [options]

Options:
  --mode <inspect|dev|prod|all>
                         inspect is read-only discovery; deployment modes
                         enforce all local, GitHub, AWS, EKS, and Docker gates
  --dev-profile <name>   Existing AWS CLI profile for account 496336474487
  --prod-profile <name>  Existing AWS CLI profile for account 125093118532
  --help                 Show this help

The command is read-only. It does not print credentials or secret values.
EOF
}

error() {
  printf 'ERROR: %s\n' "$*"
  ERRORS=$((ERRORS + 1))
}

warn() {
  printf 'WARN: %s\n' "$*"
  WARNINGS=$((WARNINGS + 1))
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --workspace)
      [ "$#" -ge 2 ] || { echo "preflight: --workspace requires a value" >&2; exit 2; }
      WORKSPACE="$2"
      shift 2
      ;;
    --app-repo)
      [ "$#" -ge 2 ] || { echo "preflight: --app-repo requires a value" >&2; exit 2; }
      APP_REPO="$2"
      shift 2
      ;;
    --mode)
      [ "$#" -ge 2 ] || { echo "preflight: --mode requires a value" >&2; exit 2; }
      MODE="$2"
      shift 2
      ;;
    --dev-profile)
      [ "$#" -ge 2 ] || { echo "preflight: --dev-profile requires a value" >&2; exit 2; }
      DEV_PROFILE="$2"
      shift 2
      ;;
    --prod-profile)
      [ "$#" -ge 2 ] || { echo "preflight: --prod-profile requires a value" >&2; exit 2; }
      PROD_PROFILE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "preflight: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$MODE" in
  inspect|dev|prod|all) ;;
  *)
    echo "preflight: unsupported --mode '$MODE' (expected inspect, dev, prod, or all)" >&2
    exit 2
    ;;
esac

if [ -z "$APP_REPO" ]; then
  echo "preflight: --app-repo is required" >&2
  exit 2
fi

if [ ! -d "$WORKSPACE" ]; then
  echo "preflight: workspace does not exist: $WORKSPACE" >&2
  exit 2
fi

WORKSPACE="$(cd "$WORKSPACE" && pwd)"

deployment_mode() {
  [ "$MODE" != "inspect" ]
}

requires_dev() {
  [ "$MODE" = "dev" ] || [ "$MODE" = "all" ]
}

requires_prod() {
  [ "$MODE" = "prod" ] || [ "$MODE" = "all" ]
}

normalize_repo_slug() {
  printf '%s\n' "$1" | sed -E \
    -e 's#^git@github\.com:##' \
    -e 's#^ssh://git@github\.com/##' \
    -e 's#^https://([^/@]+(:[^/@]*)?@)?github\.com/##' \
    -e 's#^http://([^/@]+(:[^/@]*)?@)?github\.com/##' \
    -e 's#\.git/?$##' \
    -e 's#/$##'
}

print_tool() {
  tool="$1"
  required="$2"
  if command -v "$tool" >/dev/null 2>&1; then
    printf -- '- %-12s available\n' "$tool"
  elif [ "$required" = "true" ]; then
    printf -- '- %-12s MISSING (required)\n' "$tool"
    error "required tool is missing: $tool"
  else
    printf -- '- %-12s MISSING (optional in inspect mode)\n' "$tool"
    warn "optional inspect-mode tool is missing: $tool"
  fi
}

find_repo() {
  target="$1"
  while IFS= read -r marker; do
    repo_dir="$(dirname "$marker")"
    if origin="$(git -C "$repo_dir" remote get-url origin 2>/dev/null)"; then
      slug="$(normalize_repo_slug "$origin")"
      if [ "$slug" = "$target" ]; then
        printf '%s\n' "$repo_dir"
        return 0
      fi
    fi
  done <<EOF
$(find "$WORKSPACE" -maxdepth 4 -name .git -print 2>/dev/null | sort)
EOF
  return 1
}

print_repo() {
  slug="$1"
  if ! command -v git >/dev/null 2>&1; then
    printf -- '- %s: NOT CHECKED because git is missing\n' "$slug"
    error "cannot inspect repository without git: $slug"
    return
  fi

  if repo_dir="$(find_repo "$slug")"; then
    branch="$(git -C "$repo_dir" branch --show-current 2>/dev/null || true)"
    [ -n "$branch" ] || branch="DETACHED"
    if [ -n "$(git -C "$repo_dir" status --porcelain 2>/dev/null)" ]; then
      worktree="DIRTY"
      warn "repository has uncommitted changes; inspect overlap before mutation: $slug"
    else
      worktree="clean"
    fi
    head="$(git -C "$repo_dir" rev-parse --short=12 HEAD 2>/dev/null || printf 'unknown')"
    printf -- '- %s\n' "$slug"
    printf '  path: %s\n' "$repo_dir"
    printf '  branch: %s\n' "$branch"
    printf '  head: %s\n' "$head"
    printf '  worktree: %s\n' "$worktree"
  else
    printf -- '- %s: NOT FOUND under workspace\n' "$slug"
    error "required repository checkout not found: $slug"
  fi
}

print_aws_identity() {
  label="$1"
  profile="$2"
  expected_account="$3"
  cluster="$4"
  required="$5"

  if [ -z "$profile" ]; then
    if [ "$required" = "true" ]; then
      printf -- '- %s: profile not provided (required)\n' "$label"
      error "$label profile is required for mode $MODE"
    else
      printf -- '- %s: profile not provided; live checks skipped\n' "$label"
    fi
    return
  fi

  if ! command -v aws >/dev/null 2>&1; then
    printf -- '- %s: AWS CLI missing\n' "$label"
    [ "$required" = "true" ] && error "AWS CLI is required for $label checks"
    return
  fi

  identity="$(aws sts get-caller-identity --profile "$profile" \
    --query '[Account,Arn]' --output text 2>/dev/null || true)"
  if [ -z "$identity" ]; then
    printf -- '- %s: profile %s is not authenticated\n' "$label" "$profile"
    [ "$required" = "true" ] && error "$label profile is not authenticated: $profile"
    return
  fi

  account="$(printf '%s\n' "$identity" | awk '{print $1}')"
  arn="$(printf '%s\n' "$identity" | awk '{print $2}')"
  if [ "$account" = "$expected_account" ]; then
    match="MATCH"
  else
    match="MISMATCH expected ${expected_account}"
    error "$label account mismatch: got $account, expected $expected_account"
  fi

  printf -- '- %s profile: %s\n' "$label" "$profile"
  printf '  account: %s (%s)\n' "$account" "$match"
  printf '  principal: %s\n' "$arn"

  if [ "$account" = "$expected_account" ]; then
    cluster_status="$(aws eks describe-cluster --profile "$profile" \
      --region us-east-1 --name "$cluster" --query 'cluster.status' \
      --output text 2>/dev/null || true)"
    if [ "$cluster_status" = "ACTIVE" ]; then
      printf '  shared EKS %s: %s\n' "$cluster" "$cluster_status"
    elif [ -n "$cluster_status" ]; then
      printf '  shared EKS %s: %s\n' "$cluster" "$cluster_status"
      [ "$required" = "true" ] && error "$label shared EKS is not ACTIVE: $cluster_status"
    else
      printf '  shared EKS %s: not readable or not found\n' "$cluster"
      [ "$required" = "true" ] && error "$label shared EKS is not readable: $cluster"
    fi
  fi
}

cat <<EOF
# AIAE deployment preflight

Mode: $MODE
Workspace: $WORKSPACE
Application repository: $APP_REPO

## Required tools
EOF

for tool in git gh aws terraform kubectl helm docker jq yq; do
  if [ "$tool" = "git" ] || deployment_mode; then
    print_tool "$tool" true
  else
    print_tool "$tool" false
  fi
done

cat <<'EOF'

## Local authentication
EOF

echo '- 1Password: agent access intentionally disabled; user retrieves existing credentials manually'

if command -v gh >/dev/null 2>&1; then
  if gh auth status --hostname github.com >/dev/null 2>&1; then
    echo '- GitHub CLI: authenticated to github.com'
  else
    echo '- GitHub CLI: not authenticated to github.com'
    if deployment_mode; then
      error 'GitHub CLI authentication is required for deployment modes'
    else
      warn 'GitHub CLI is not authenticated; remote inspection is unavailable'
    fi
  fi
else
  echo '- GitHub CLI: unavailable'
fi

cat <<'EOF'

## Repository checkouts
EOF

print_repo 'AiDigital-com/AIAE-helm'
print_repo 'AiDigital-com/AIAE-helm-versions'
print_repo 'AiDigital-com/AIAE-aws-infra'
print_repo "$APP_REPO"

cat <<'EOF'

## AWS identities and shared clusters
EOF

if requires_dev; then dev_required=true; else dev_required=false; fi
if requires_prod; then prod_required=true; else prod_required=false; fi
print_aws_identity 'DEV' "$DEV_PROFILE" '496336474487' 'aiae-operational-hub-dev' "$dev_required"
print_aws_identity 'PROD' "$PROD_PROFILE" '125093118532' 'aiae-operational-hub-prod' "$prod_required"

cat <<'EOF'

## Local runtime
EOF

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    echo '- Docker daemon: reachable'
  else
    echo '- Docker daemon: not reachable'
    if deployment_mode; then
      error 'Docker daemon is required for deployment modes'
    else
      warn 'Docker daemon is not reachable; image builds cannot be verified'
    fi
  fi
else
  echo '- Docker daemon: Docker CLI missing'
fi

cat <<EOF

## Result

Errors: $ERRORS
Warnings: $WARNINGS
EOF

if [ "$ERRORS" -gt 0 ]; then
  echo 'Status: FAILED'
  echo 'Resolve all errors and rerun preflight before Terraform planning or deployment.'
  exit 1
fi

echo 'Status: PASS'
if [ "$WARNINGS" -gt 0 ]; then
  echo 'Review warnings before mutation; dirty repositories may still block overlapping edits.'
fi
exit 0
