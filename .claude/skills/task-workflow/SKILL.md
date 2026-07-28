---
name: task-workflow
description: Multi-role iterative enterprise development workflow with context-isolated task artifacts
---

<!--
Generated file. Do not edit directly.
Source: AIAE-llm-aux/skills/task-workflow/SKILL.md.template
Revision: d8f00e9689669785367c31e97fc5ed2229e7eb0d
Target: claude
-->


Run a structured multi-role enterprise development workflow for: **$ARGUMENTS**.
If this runtime does not expand `$ARGUMENTS`, use the user's latest request as
the task description and ask one concise question only when it is ambiguous.

Arguments: `<task ID or short description> [| <context prompt for the analytic role>] [| mode: <plan|execute|autonomous>]`.

Parse `$ARGUMENTS` by splitting on ` | ` separators:

- **Part 1**: task identifier or short description
- **Part 2** (optional): context for the analytic role
- **mode:** segment (optional): one of `plan`, `execute`, `autonomous`

Derive `<task>` from Part 1:
- if it already looks like a task ID, keep it as-is
- otherwise slugify the description

Default mode is `plan` when no mode is supplied.

## Modes

### `plan`
Produce the analysis and implementation plan, write it to `plan.md`, then stop.
Do not modify code.

### `execute`
Produce the plan, present it, and require explicit user approval before
implementing. After approval, run the developer, reviewer, and tester roles.
Stop at the end of each role if the user requests changes.

### `autonomous`
Complete analysis, implementation, review, and verification without
intermediate approval unless blocked by missing information or a safety
constraint. Still stop immediately if a blocking ambiguity, a destructive
operation, or a safety constraint is encountered.

## Task state

Each role works through files in `.claude/tasks/<task>/`. The orchestrator
should stay lightweight and use those files as the task state.

The renderer replaces `.claude/tasks` with the repository's configured
shared task directory at sync time.

## Repository rules

Before any role begins, read and apply the repository-local instructions that
govern implementation and review:

- the project `CLAUDE.md` (or `AGENTS.md` when the active agent reads it);
- the applicable rules under `.claude/rules/` (or the project's rule directory);
- the relevant agent docs and project-specific skills referenced by those rules.

Do not duplicate stack, framework, styling, auth, or test-style rules inside
this skill. Those live in the repository contract and may change without
notice. If a rule source is missing, record that gap in the plan and proceed
only with universally safe defaults.

## Step 1 — Analytic role

Create `.claude/tasks/<task>/plan.md`.

The plan must contain:

### 1. Context / Problem Statement
Describe the current behavior and the problem to solve.

### 2. Acceptance Criteria
Each item starts with `[ ]` and is testable.

### 3. Step-by-Step Implementation Plan
Numbered steps. Each step names the exact file paths to modify or create and
explains why.

### 4. Test Coverage Plan
Discover and use only the test layers that actually exist in the current
repository. List the concrete test layers you found and the ones you will use.
If no dedicated integration-test layer exists, write:
`No dedicated integration-test layer in this repository.`

### 5. Verification Approach
Explain how to verify the implementation with the project's actual build,
test, typecheck, and static-gate commands. Discover these commands from the
repository; do not assume a fixed command set.

### 6. Rule sources loaded
List the `CLAUDE.md` / `AGENTS.md`, rule files, and agent docs you read. If a
rule source was missing, record it here.

After writing the plan:
- in `plan` mode, stop and present the plan;
- in `execute` mode, present the plan and wait for explicit user approval
  before proceeding;
- in `autonomous` mode, proceed to Step 2.

If the user requests changes, revise the same `plan.md` file.

## Step 2 — Developer role

Read `.claude/tasks/<task>/plan.md` in full before editing code.

Implement following the repository rules loaded in Step 1. Do not restate those
rules here; apply them. If a repository rule conflicts with the plan, stop and
record the conflict rather than silently picking one side.

Do not stage, commit, or push files automatically. The workflow does not
modify the Git staging area or history. Leave all version-control actions to
the user unless the user explicitly requests a commit at the end.

Run the project's compile/check commands for touched areas, discovered from the
repository. Record the commands you ran and their outcomes.

Then write `.claude/tasks/<task>/dev-summary.md` with:

```md
## Changed Files
- path — change summary

## Affected Areas
- <area/module>

## Tests Added or Expanded
- path — what was covered
- OR: None

## Build/check commands run
- command — outcome

## Summary
2-3 sentences describing the implementation.
```

## Step 3 — Reviewer role

Read `.claude/tasks/<task>/dev-summary.md`, inspect the diff, and review
the changed files against the repository rules loaded in Step 1.

Review focus:
1. Correctness of the change against the plan's acceptance criteria.
2. Conformance to the repository rules you loaded (architecture, boundaries,
   configuration, typing, generated-source safety, test style).
3. Edge cases, error handling, and failure behavior introduced or exposed by
   the change.
4. Authorization, concurrency, transaction, and external-call risks where
   applicable.
5. Meaningful test regression gaps (not trivial generated/Lombok behavior).

Report only verified findings. Do not report raw scanner matches, speculative
issues, or stylistic preferences as defects. Do not include a mandatory
"Positive Observations" section; lead with actionable findings.

Write `.claude/tasks/<task>/review.md` with:
- `STATUS: APPROVED` or `STATUS: CHANGES_REQUESTED`
- Scope: files/range reviewed
- Findings: ordered by severity, each with `file:line — problem — impact — fix`
- Rule sources used
- Verification commands run and outcomes (or not run, with reason)

If the review requests changes, return to the Developer role with the report as
mandatory input.

## Step 4 — Tester role

Read `.claude/tasks/<task>/dev-summary.md` and run tests for the affected
areas using the project's actual test commands, discovered from the repository.

Check:
- whether tests pass;
- whether changed classes/components have matching coverage where appropriate;
- whether any important acceptance-criteria path is still untested.

Write `.claude/tasks/<task>/verification.md` with:
- `STATUS: PASSED` or `STATUS: FAILED`
- Test run results (commands and outcomes)
- Failures (if any)
- Coverage notes
- Unverified gaps and reasons

If tests fail, return to the Developer role with the report as mandatory input.

## Loop termination

The workflow ends when the review is approved and the verification report is
`STATUS: PASSED`, or when the user stops the workflow.

## Final summary

At the end, read `plan.md`, `dev-summary.md`, `review.md`, and
`verification.md`, then provide:
- Technical Resolution
- Business Resolution
- Suggested commit message (do not commit unless the user explicitly asks)

Commit message format:

```text
<TASK-ID-OR-SHORT-SLUG> <Short imperative description>
```

Do not assume any fixed ticket prefix unless the user explicitly supplied one.
