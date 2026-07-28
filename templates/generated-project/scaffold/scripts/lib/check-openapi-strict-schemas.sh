#!/usr/bin/env bash
#
# check-openapi-strict-schemas.sh — rejects loose OpenAPI DTO schemas.
#
# Usage:
#   bash scripts/lib/check-openapi-strict-schemas.sh [openapi.yaml] [generated-schema.d.ts]
#
# Override OPENAPI_DYNAMIC_SCHEMA_ALLOW_RE only for deliberate project-specific
# dynamic helper schemas. Do not add regular request/response DTOs to it.

set -euo pipefail

spec_path="${1:-backend/application/src/main/resources/api/v1/specs/openapi.yaml}"
ts_schema_path="${2:-frontend/src/shared/api/generated/schema.d.ts}"
dynamic_allow_re="${OPENAPI_DYNAMIC_SCHEMA_ALLOW_RE:-^(JsonMetadata|JsonPayload|ProviderPayload|WebhookPayload|JwtClaims)V[0-9]+$}"

fail() {
  echo "check-openapi-strict-schemas: $*" >&2
  exit 1
}

[ -f "${spec_path}" ] || fail "missing OpenAPI spec: ${spec_path}"

awk -v allow_re="${dynamic_allow_re}" '
function emit(line, message) {
  printf "%s:%d: %s\n", FILENAME, line, message
  found = 1
}
function leading_spaces(line, copy) {
  copy = line
  sub(/[^ ].*$/, "", copy)
  return length(copy)
}
function reset_schema() {
  if (schema_name != "" && schema_is_object) {
    if (schema_additional == "true" && schema_name !~ allow_re) {
      emit(schema_additional_line, "top-level schema " schema_name " is loose; use additionalProperties: false or move the dynamic map into an allowlisted helper schema")
    }
    if (schema_additional == "") {
      emit(schema_line, "top-level object schema " schema_name " must explicitly set additionalProperties: false")
    }
  }
  schema_name = ""
  schema_line = 0
  schema_is_object = 0
  schema_additional = ""
  schema_additional_line = 0
}
/^components:/ { in_components = 1; next }
in_components && /^[a-zA-Z][^:]*:/ { reset_schema(); in_components = 0 }
in_components && /^  schemas:/ { in_schemas = 1; next }
in_schemas && /^  [a-zA-Z][^:]*:/ { reset_schema(); in_schemas = 0 }
in_schemas && /^    [A-Za-z0-9_.-]+:/ {
  reset_schema()
  schema_name = $1
  sub(/:$/, "", schema_name)
  schema_line = NR
  next
}
schema_name != "" && leading_spaces($0) == 6 && $1 == "type:" && $2 == "object" {
  schema_is_object = 1
}
schema_name != "" && leading_spaces($0) == 6 && $1 == "additionalProperties:" {
  schema_additional = $2
  schema_additional_line = NR
}
END { reset_schema(); exit found ? 1 : 0 }
' "${spec_path}" || fail "top-level component object schemas must be closed unless allowlisted as dynamic helper schemas"

if grep -nE 'items:[[:space:]]*\{[^}]*additionalProperties:[[:space:]]*true|additionalProperties:[[:space:]]*true[^{]*\}[[:space:]]*$' "${spec_path}" >/dev/null; then
  grep -nE 'items:[[:space:]]*\{[^}]*additionalProperties:[[:space:]]*true|additionalProperties:[[:space:]]*true[^{]*\}[[:space:]]*$' "${spec_path}" >&2
  fail "inline loose object schemas are forbidden; create a named strict DTO or isolate a typed dynamic map field"
fi

if [ -f "${ts_schema_path}" ]; then
  awk -v allow_re="${dynamic_allow_re}" '
  function leading_spaces(line, copy) {
    copy = line
    sub(/[^ ].*$/, "", copy)
    return length(copy)
  }
  /^[[:space:]]+[A-Za-z0-9_.-]+: \{$/ {
    indent = leading_spaces($0)
    # openapi-typescript component schema entries usually appear at 8 spaces;
    # tests and older generated output may use 4. Inline object fields are deeper.
    if (indent <= 8) {
      schema = $1
      sub(/:$/, "", schema)
      schema_indent = indent
    }
    next
  }
  schema != "" && leading_spaces($0) > schema_indent && /^[[:space:]]+\[key: string\]: unknown;/ {
    if (schema !~ allow_re) {
      printf "%s:%d: generated schema %s has an unknown index signature\n", FILENAME, NR, schema
      found = 1
    }
  }
  schema != "" && leading_spaces($0) == schema_indent && /^[[:space:]]+\};$/ { schema = "" }
  END { exit found ? 1 : 0 }
  ' "${ts_schema_path}" || fail "generated frontend types contain unknown index signatures for non-allowlisted schemas"
fi

echo "check-openapi-strict-schemas: passed"
