#!/usr/bin/env bash
# Fixture tests for scaffold/scripts/lib/check-api-client-paths.sh.
#
# This gate had no test of any kind. It is the only thing that catches a frontend
# calling an endpoint the OpenAPI contract does not define — a mismatch that
# compiles, ships, and fails at runtime with a 404 the types promised could not
# happen.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "${HERE}/../../.." && pwd)"
GATE="${REPO}/templates/generated-project/scaffold/scripts/lib/check-api-client-paths.sh"
. "${HERE}/../lib/assert.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

SPEC_REL="backend/application/src/main/resources/api/v1/specs/openapi.yaml"
# The gate resolves both arguments relative to the working directory.
run_gate() { ( cd "$1" && bash "${GATE}" "${SPEC_REL}" frontend/src ); }

synth() {
  local name="$1" dir="${WORK}/$1"
  rm -rf "$dir"
  mkdir -p "${dir}/$(dirname "${SPEC_REL}")" "${dir}/frontend/src/features"
  cat > "${dir}/${SPEC_REL}" <<'EOF'
openapi: 3.0.3
info:
  title: Demo
  version: 1.0.0
paths:
  /api/v1/widgets:
    get:
      operationId: listWidgets
      responses:
        "200":
          description: OK
    post:
      operationId: createWidget
      responses:
        "201":
          description: Created
  /api/v1/widgets/{id}:
    get:
      operationId: getWidget
      responses:
        "200":
          description: OK
components:
  schemas: {}
EOF
  printf '%s' "$dir"
}

echo "==> positive"

F="$(synth valid)"
cat > "${F}/frontend/src/features/widgets.ts" <<'EOF'
export const list = () => apiClient.GET("/api/v1/widgets");
export const create = () => apiClient.POST("/api/v1/widgets");
export const one = () => apiClient.GET("/api/v1/widgets/{id}");
EOF
gate_accepts "every apiClient call is defined in the contract" "${F}" -- run_gate "${F}"

echo "==> violation classes"

F="$(synth undefined-path)"
cat > "${F}/frontend/src/features/widgets.ts" <<'EOF'
export const ghost = () => apiClient.GET("/api/v1/gadgets");
EOF
gate_rejects "path absent from the contract" "${F}" \
  'apiClient.GET("/api/v1/gadgets") is not defined' -- run_gate "${F}"

# The path exists but not for this verb. Without method awareness the gate would
# accept a DELETE against a read-only resource.
F="$(synth undefined-method-on-known-path)"
cat > "${F}/frontend/src/features/widgets.ts" <<'EOF'
export const remove = () => apiClient.DELETE("/api/v1/widgets");
EOF
gate_rejects "verb not declared for an existing path" "${F}" \
  'apiClient.DELETE("/api/v1/widgets") is not defined' -- run_gate "${F}"

F="$(synth undefined-in-tsx)"
mv "${F}/frontend/src/features" "${F}/frontend/src/pages"
cat > "${F}/frontend/src/pages/WidgetPage.tsx" <<'EOF'
export function WidgetPage() {
  const load = () => apiClient.GET("/api/v1/widgets/all");
  return null;
}
EOF
gate_rejects "violation inside a .tsx file is scanned too" "${F}" \
  'apiClient.GET("/api/v1/widgets/all") is not defined' -- run_gate "${F}"

echo "==> known fail-open behaviour"

# With no spec, or no frontend tree, the gate exits 0 silently. That is a real
# bypass in a full-stack project: deleting or moving the spec disables the check
# rather than failing it. Pinned so the behaviour cannot change unnoticed; whether
# it should fail closed is the same decision already taken for the coverage gate.
F="$(synth spec-absent)"
cat > "${F}/frontend/src/features/widgets.ts" <<'EOF'
export const ghost = () => apiClient.GET("/api/v1/definitely-not-real");
EOF
rm -f "${F}/${SPEC_REL}"
gate_accepts "absent spec silently skips the check" "${F}" -- run_gate "${F}"

F="$(synth frontend-absent)"
rm -rf "${F}/frontend"
gate_accepts "absent frontend tree silently skips the check" "${F}" -- run_gate "${F}"

gate_summary "test-gate-api-client-paths"
