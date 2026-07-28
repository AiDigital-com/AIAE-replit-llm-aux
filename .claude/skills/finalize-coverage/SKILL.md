---
name: finalize-coverage
description: Raise test coverage to the strict gate and switch the project from the MVP phase to the engineering phase. Use when the user says the project is finished, ready for handoff, ready for engineering, or asks to finalize coverage, finish tests, or complete the last step before handing the project over.
metadata:
  user-invocable: "true"
---

# Finalize Coverage

The required last step before a project leaves for engineering.

While the product is being built the project sits in the **MVP phase** and the
coverage gate is deliberately relaxed, so tests never block feature discovery.
Once the human says the project is done, coverage becomes the finishing work.
This step is not optional and there is no flag that skips it:
`prepare-engineering-handoff.sh` refuses to run while the phase is `mvp`, and
lowering the thresholds instead is rejected by
`scripts/lib/check-coverage-integrity.sh`.

Write tests. Do not lower gates.

## Step 1 — confirm the project is actually finished

Ask once, plainly: is feature work complete? If more features are coming, stop —
finalizing now means doing it twice. Say that and leave the phase alone.

## Step 2 — establish the real number

```bash
cat .template-phase
mvn -f backend/pom.xml -B -Pmvp clean verify
```

Then read the per-module JaCoCo reports at
`backend/*/target/site/jacoco/jacoco.xml` and record, per module, current line
and branch coverage. Report the actual starting point before changing anything —
the user needs to know how much work this is.

The targets are the pom defaults: **0.80 line, 0.70 branch**, per module
(`BUNDLE` scope). Generated OpenAPI code is already excluded; do not add
excludes.

## Step 3 — close the gap, module by module

Work one module at a time, lowest coverage first. For each:

1. List the uncovered classes and methods from the JaCoCo report.
2. Skip what is genuinely not worth testing and say why — DTOs with only Lombok
   members, generated code, trivial getters.
3. Write real tests for the rest, following `.claude/rules/20-tests.md`. Behavior
   and boundaries, not assertions written to touch lines.
4. Re-run that module and confirm the number moved.

Rules that matter here:

- Tests must assert behavior. A test that executes code without asserting
  anything raises the metric and lowers the value of the suite; that is the same
  cheat as lowering the gate, one layer up.
- Do not add `<exclude>` entries to escape a hard-to-test class. Extract the
  logic into a collaborator and test that — the backend rules already require
  non-private, spyable methods for exactly this reason.
- Integration tests using Testcontainers Postgres count. Prefer them where the
  behavior is a query or a transaction boundary.

## Step 4 — flip the phase

Only after the strict gate passes on every module:

```bash
mvn -f backend/pom.xml -B clean verify     # no -Pmvp: this is the strict gate
echo engineering > .template-phase
bash scripts/local-verify.sh
```

The bare `mvn verify` is the real test — the strict thresholds are the pom
defaults, so no flag is needed to be strict.

This flip is one-way. `check-coverage-integrity.sh` fails the build if
`.template-phase` is later reverted from `engineering` to `mvp`, so do not flip
it early "to see what happens".

## Step 5 — report

State per module: starting coverage, final coverage, and how many tests were
added. If any code was deliberately left untested, list it and the reason, so
the receiving team inherits a known list rather than a surprise.

Then confirm the project is ready for `engineering-handoff`.

## If coverage cannot reach the gate

Say so directly, with the specific blocker. Do not lower the threshold, add
excludes, or write assertion-free tests to close the gap. An honest "this module
needs refactoring before it can be tested" is a useful result; a green build that
means nothing is not.
