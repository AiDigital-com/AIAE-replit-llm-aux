#!/usr/bin/env bash
#
# check-coverage-integrity.sh — stop the coverage gate from being neutered.
#
# A threshold is only as strong as the ways around it. This check closes the
# cheap ones: skip flags, lowered numbers, widened excludes, and a phase marker
# quietly reverted to `mvp` after the project already reached `engineering`.
#
# It cannot make the gate impossible to bypass — anyone who can edit pom.xml can
# edit a number. What it does is make every bypass a visible, reviewable change
# instead of an invisible command-line flag.
#
# Checks:
#   1. .template-phase is present and holds a known value
#   2. the phase never regresses from engineering back to mvp
#   3. the strict default in backend/pom.xml is still >= 0.80 line / 0.70 branch
#   4. the mvp floor is still >= 0.30 line / 0.25 branch
#   5. no coverage/test skip flags outside the one place a deploy build needs one
#   6. jacoco <excludes> covers only generated code, not hand-written packages
#   7. no -Djacoco.* threshold overrides anywhere

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${VERIFY_ROOT:-$(pwd)}"
POM="${ROOT}/backend/pom.xml"

# shellcheck source=./coverage-phase.sh
. "${SCRIPT_DIR}/coverage-phase.sh"

errors=0
fail() {
  echo "check-coverage-integrity: FAIL — $*" >&2
  errors=$((errors + 1))
}

if [ ! -f "$POM" ]; then
  # A missing backend pom used to pass as "skipped", which made deleting the pom
  # a silent way to disable coverage enforcement in a full-stack project. There is
  # no frontend-only scaffold yet, so absence cannot mean "intentionally has no
  # backend" — it means the gate has nothing to check and must say so.
  #
  # When a real frontend-only shape exists, it declares itself; the shape is never
  # inferred from which files happen to be missing.
  if [ -f "${ROOT}/.project-shape" ] \
      && [ "$(tr -d '[:space:]' < "${ROOT}/.project-shape")" = "frontend-only" ]; then
    echo "check-coverage-integrity: skipped (.project-shape declares frontend-only)"
    exit 0
  fi
  echo "check-coverage-integrity: FAIL — backend/pom.xml is absent, so no coverage gate exists." >&2
  echo "       A full-stack project must carry the backend pom that defines the" >&2
  echo "       jacoco thresholds. If this project genuinely has no backend, declare" >&2
  echo "       it explicitly by writing 'frontend-only' to .project-shape; the shape" >&2
  echo "       is never inferred from missing files." >&2
  exit 1
fi

# --- 1. phase marker present and valid -------------------------------------
PHASE=""
if ! PHASE="$(coverage_phase_read "$ROOT")"; then
  fail "cannot determine coverage phase"
  PHASE="engineering"
fi

if [ ! -f "${ROOT}/${COVERAGE_PHASE_FILE}" ]; then
  fail "${COVERAGE_PHASE_FILE} is missing.
       The coverage phase must be an explicit, committed decision. Create it with
       'mvp' while building, or 'engineering' once coverage is finalized."
fi

# --- 2. phase must not regress --------------------------------------------
# Once a project has declared `engineering`, dropping back to `mvp` would relax
# the final gate after it was met. Detect it from history rather than trusting
# the current value alone.
if [ "$PHASE" = "mvp" ] && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  if git -C "$ROOT" log --all -p -- "${COVERAGE_PHASE_FILE}" 2>/dev/null \
      | grep -qx '+engineering'; then
    fail "${COVERAGE_PHASE_FILE} was reverted from 'engineering' back to 'mvp'.
       Coverage finalization is a one-way step. If this is intentional, it needs
       an explicit decision on the record, not a silent revert."
  fi
fi

# --- 3 & 4. thresholds not lowered ----------------------------------------
# Compare as integers scaled by 100; bash has no float comparison.
scaled() { awk -v v="$1" 'BEGIN { printf "%d", (v * 100) + 0.5 }'; }

read_default_prop() {
  # First occurrence outside any <profile> is the default. The properties block
  # sits well above <profiles>, so take the first match.
  grep -o "<$1>[^<]*</$1>" "$POM" | head -1 | sed "s|</\{0,1\}$1>||g"
}

read_profile_prop() {
  # Value inside the named profile.
  awk -v id="$1" -v prop="$2" '
    $0 ~ "<id>" id "</id>" { inp = 1 }
    inp && $0 ~ "<" prop ">" {
      line = $0
      sub(".*<" prop ">", "", line)
      sub("</" prop ">.*", "", line)
      print line
      exit
    }
    inp && /<\/profile>/ { inp = 0 }
  ' "$POM"
}

def_line="$(read_default_prop jacoco.line.coverage || true)"
def_branch="$(read_default_prop jacoco.branch.coverage || true)"

if [ -z "$def_line" ] || [ -z "$def_branch" ]; then
  fail "cannot read default jacoco thresholds from backend/pom.xml"
else
  if [ "$(scaled "$def_line")" -lt "$(scaled "$COVERAGE_STRICT_LINE_MIN")" ]; then
    fail "default jacoco.line.coverage is ${def_line}, below the required ${COVERAGE_STRICT_LINE_MIN}.
       The default is the final gate; it must stay strict. Use the mvp phase for relaxation."
  fi
  if [ "$(scaled "$def_branch")" -lt "$(scaled "$COVERAGE_STRICT_BRANCH_MIN")" ]; then
    fail "default jacoco.branch.coverage is ${def_branch}, below the required ${COVERAGE_STRICT_BRANCH_MIN}."
  fi
fi

mvp_line="$(read_profile_prop mvp jacoco.line.coverage || true)"
mvp_branch="$(read_profile_prop mvp jacoco.branch.coverage || true)"

if [ -n "$mvp_line" ]; then
  if [ "$(scaled "$mvp_line")" -lt "$(scaled "$COVERAGE_MVP_LINE_MIN")" ]; then
    fail "mvp profile jacoco.line.coverage is ${mvp_line}, below the floor ${COVERAGE_MVP_LINE_MIN}.
       A zero or near-zero floor lets coverage start at nothing and makes the final climb a wall."
  fi
fi
if [ -n "$mvp_branch" ]; then
  if [ "$(scaled "$mvp_branch")" -lt "$(scaled "$COVERAGE_MVP_BRANCH_MIN")" ]; then
    fail "mvp profile jacoco.branch.coverage is ${mvp_branch}, below the floor ${COVERAGE_MVP_BRANCH_MIN}."
  fi
fi

# --- 5. no skip flags on any verification surface -------------------------
# Skip flags are not wrong everywhere. `-DskipTests` in a Dockerfile or in the
# Replit dev-run command is correct: those produce or boot an artifact, they do
# not claim to verify anything. The same flag in local-verify.sh is a bypass.
#
# So enumerate the surfaces that must be clean, rather than trying to enumerate
# every legitimate exception. Anything asserting "this project is verified" is
# listed here; build and run entry points deliberately are not.
#
# Note: file lists are built with `find`, not `grep --include`. grep on this
# machine may be ugrep, whose --include semantics differ from GNU grep, and a
# scanner that silently widens its own scope is worse than no scanner.
SELF_REL="scripts/lib/check-coverage-integrity.sh"

GATE_FILES=()
for candidate in \
  scripts/local-verify.sh \
  scripts/verify-gates.sh \
  scripts/structure-lint.sh
do
  [ -f "${ROOT}/${candidate}" ] && GATE_FILES+=("${candidate}")
done

# Every gate helper except this one.
while IFS= read -r f; do
  rel="${f#"${ROOT}/"}"
  [ "$rel" = "$SELF_REL" ] && continue
  GATE_FILES+=("$rel")
done < <(find "${ROOT}/scripts/lib" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sort)

# CI workflows assert verification, so they are gate surfaces too.
while IFS= read -r f; do
  GATE_FILES+=("${f#"${ROOT}/"}")
done < <(find "${ROOT}/.github/workflows" -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort)

SKIP_FLAG_RE='-D(jacoco\.skip|maven\.test\.skip|skipTests|checkstyle\.skip)'

# Empty when none of the verification surfaces exist; bash 3.2 treats a bare
# "${arr[@]}" on an empty array as unbound under set -u.
for rel in ${GATE_FILES[@]+"${GATE_FILES[@]}"}; do
  file="${ROOT}/${rel}"
  [ -f "$file" ] || continue
  while IFS= read -r line; do
    trimmed="$(printf '%s' "$line" | sed 's/^[[:space:]]*//')"
    case "$trimmed" in '#'*) continue ;; esac
    fail "coverage/test bypass on a verification surface — ${rel}: ${trimmed}"
  done < <(grep -E -- "$SKIP_FLAG_RE" "$file" 2>/dev/null || true)

  while IFS= read -r line; do
    trimmed="$(printf '%s' "$line" | sed 's/^[[:space:]]*//')"
    case "$trimmed" in '#'*) continue ;; esac
    fail "threshold override on a verification surface — ${rel}: ${trimmed}
       Thresholds belong in backend/pom.xml where they are reviewable. Use -Pmvp."
  done < <(grep -E -- '-Djacoco\.(line|branch)\.coverage' "$file" 2>/dev/null || true)
done

# Poms: the element form is configuration, never prose, so it is unambiguous.
while IFS= read -r pom; do
  rel="${pom#"${ROOT}/"}"
  while IFS= read -r line; do
    fail "coverage/test skip property in ${rel}: $(printf '%s' "$line" | sed 's/^[[:space:]]*//')"
  done < <(grep -E '<(jacoco\.skip|maven\.test\.skip|skipTests)>[[:space:]]*true' "$pom" 2>/dev/null || true)
done < <(find "${ROOT}/backend" -name 'pom.xml' -not -path '*/target/*' 2>/dev/null | sort)

# --- 6. excludes limited to generated code --------------------------------
# The allowlist mirrors the generated OpenAPI output. Anything else being
# excluded is hand-written code hidden from the gate.
ALLOWED_EXCLUDES='\*\*/api/v1/model/\*\*|\*\*/api/v1/invoker/\*\*|\*\*/api/v1/\*Api\.class'
while IFS= read -r ex; do
  value="$(printf '%s' "$ex" | sed 's|.*<exclude>||; s|</exclude>.*||')"
  if ! printf '%s' "$value" | grep -qE "^(${ALLOWED_EXCLUDES})$"; then
    fail "jacoco <exclude> '${value}' is not generated code.
       Excluding hand-written packages hides them from the coverage gate."
  fi
done < <(awk '/<artifactId>jacoco-maven-plugin/{inj=1} inj && /<exclude>/{print} inj && /<\/plugin>/{inj=0}' "$POM")

if [ "$errors" -gt 0 ]; then
  echo "check-coverage-integrity: ${errors} problem(s)" >&2
  exit 1
fi

echo "check-coverage-integrity: OK (phase=${PHASE}, strict ${def_line}/${def_branch}, mvp ${mvp_line:-n/a}/${mvp_branch:-n/a})"
