#!/usr/bin/env bash
# install-fixture-aggregate.sh — derive a real aggregate from the scaffold sample.
#
# Why this exists: strip-scaffold-samples.sh removes the reference aggregate, and
# the stripped project is the one every real project actually is — yet nothing ever
# built it. A defect in exactly that variant shipped: the stripper left an
# unterminated XML comment, so Liquibase refused to parse the changelog in every
# stripped project.
#
# Building the stripped variant needs code, because a project with no aggregate
# proves nothing about compilation or coverage. That code is derived from the
# sample by renaming rather than hand-written. A parallel hand-written aggregate
# would have to satisfy every gate independently — JavaDoc on every method, no
# private methods in beans, no nested types, Lombok in each module, preConditions
# on the changeSet, `should` test naming, the coverage floor — and would rot the
# moment the sample changed. Derivation keeps it correct by construction.
#
# Usage:
#   tests/lifecycle/install-fixture-aggregate.sh <project-root> [aggregate-name]
#
# Run before strip-scaffold-samples.sh: the fixture brings its own changeSet and
# <include>, and the stripper removes only the sample's.
set -euo pipefail

ROOT="${1:?Usage: install-fixture-aggregate.sh <project-root> [aggregate-name]}"
NAME="${2:-widget}"

[ -d "${ROOT}/backend" ] || { echo "install-fixture-aggregate: no backend/ under ${ROOT}" >&2; exit 1; }

# Capitalise for class names without relying on bash 4 (${x^}), absent on macOS.
CAP="$(printf '%s' "$NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
PLURAL="${NAME}s"

CHANGELOG="${ROOT}/backend/migrations/src/main/resources/db/changelog"
SAMPLE_CHANGESET="${CHANGELOG}/changes/0002-sample-reference.xml"
MASTER="${CHANGELOG}/db.changelog-master.xml"

sample_dirs=()
while IFS= read -r dir; do sample_dirs+=("$dir"); done < <(
  find "${ROOT}/backend" -type d -name sample -not -path '*/target/*' | LC_ALL=C sort
)
[ "${#sample_dirs[@]}" -gt 0 ] \
  || { echo "install-fixture-aggregate: no sample aggregate found — already stripped?" >&2; exit 1; }

# The reference-only banner is a run of `//` lines fenced by two box-drawing rules,
# exactly two per file. Delete that block, plus any stray marker line in the one
# file that carries no fence.
#
# Order matters: strip before renaming. Renaming first turned
# `strip-scaffold-samples.sh` into `strip-scaffold-widgets.sh` and `Scaffold sample`
# into `Scaffold widget`, so the markers no longer matched and banner fragments
# survived into the derived aggregate.
strip_banner() {
  awk '
    !done && /^[[:space:]]*\/\/[[:space:]]*[─═]{3,}[[:space:]]*$/ {
      if (inside) { inside = 0; done = 1 } else { inside = 1 }
      next
    }
    inside { next }
    /^[[:space:]]*\/\/.*(SCAFFOLD EXAMPLE|REFERENCE ONLY|MUST be stripped|strip-scaffold-samples\.sh)/ { next }
    { print }
  '
}

rename_stream() {
  # Longest-first so `SampleEntity` is not left as `WidgetEntity`-adjacent debris.
  sed -e "s/Sample/${CAP}/g" -e "s/sample/${NAME}/g" -e "s/samples/${PLURAL}/g"
}

transform() { strip_banner | rename_stream; }

copied=0
for dir in "${sample_dirs[@]}"; do
  target="${dir%/sample}/${NAME}"
  mkdir -p "$target"
  while IFS= read -r file; do
    base="$(basename "$file" | rename_stream)"
    transform < "$file" > "${target}/${base}"
    copied=$((copied + 1))
  done < <(find "$dir" -maxdepth 1 -type f -name '*.java')

  # Nested packages (entities/, repositories/, models/, services/, services/impl).
  while IFS= read -r sub; do
    rel="${sub#"$dir"/}"
    mkdir -p "${target}/${rel}"
    while IFS= read -r file; do
      base="$(basename "$file" | rename_stream)"
      transform < "$file" > "${target}/${rel}/${base}"
      copied=$((copied + 1))
    done < <(find "$sub" -maxdepth 1 -type f -name '*.java')
  done < <(find "$dir" -mindepth 1 -type d | LC_ALL=C sort)
done


if [ -f "$SAMPLE_CHANGESET" ]; then
  fixture_changeset="${CHANGELOG}/changes/0004-${NAME}-aggregate.xml"
  # Drop the sample's deletion banner as well, then rename table and changeSet id.
  awk '/<!--/{c=1} c&&/-->/{c=0;next} !c{print}' "$SAMPLE_CHANGESET" \
    | sed -e "s/sample-reference-initial/${NAME}-aggregate-initial/" \
          -e "s/\"samples\"/\"${PLURAL}\"/g" \
    > "$fixture_changeset"

  # Insert the include before the sample's, so ordering stays deterministic and the
  # stripper's removal of the sample line cannot take this one with it.
  awk -v line="    <include file=\"db/changelog/changes/0004-${NAME}-aggregate.xml\"/>" '
    /0003-cache-invalidation\.xml/ { print line }
    { print }
  ' "$MASTER" > "${MASTER}.tmp" && mv "${MASTER}.tmp" "$MASTER"
fi

echo "==> install-fixture-aggregate: installed '${NAME}' aggregate (${copied} source file(s))"
echo "    Derived from the scaffold sample; run strip-scaffold-samples.sh next."
