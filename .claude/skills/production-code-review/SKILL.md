---
name: production-code-review
description: Evidence-based production code review of a requested scope, local changes, or a supplied commit. Reports verified findings only and requires task context before review.
---

<!--
Generated file. Do not edit directly.
Source: AIAE-llm-aux/skills/production-code-review/SKILL.md
Revision: 690a9748657adf81d01702dafa2c7ecc8afcf5c5
Target: claude
-->


# Production code review

Use the user request as scope when `$ARGUMENTS` is not expanded by the runtime.
If no scope is supplied, review local changes first; if there are none, ask for
the intended area rather than silently reviewing an arbitrary history range.

## Required context

Before reviewing, read the task description, acceptance criteria, relevant
repository instructions, and the affected architecture/rules. Establish what
the code is meant to do, which compatibility/security/performance constraints
apply, and what tests or evidence already exist.

## Review method

1. Inspect the change and its callers/callees, not only changed lines.
2. Trace inputs, authorization, state changes, error paths, concurrency,
   persistence, API compatibility, resource use, and observability.
3. Check tests for meaningful coverage of the changed behavior and failure
   modes. Run focused verification when feasible; distinguish unrun checks.
4. Report a finding only when you can explain the reachable path, failure mode,
   impact, and a specific location. Do not turn style preferences or missing
   proof into defects.
5. Respect repository rules. If an architecture concern is not covered by a
   rule, label it as advice rather than a violation.

## Finding standard

Each finding must include severity, file/location, trigger, consequence,
evidence, and a practical correction. Use these severities:

- **Critical**: data loss/exposure, auth bypass, outage, or irreversible harm.
- **High**: likely production failure, major correctness/security regression.
- **Medium**: bounded but material defect, maintainability risk with a clear
  failure path, or inadequate validation of changed behavior.
- **Low**: concrete non-blocking issue.

If no verified findings exist, say so and list remaining evidence gaps. Do not
manufacture positives or generic best-practice advice.

## Output

1. **Scope and evidence** — task context, files/rules read, commands run.
2. **Verified findings** — ordered by severity; omit the section or state none.
3. **Evidence gaps / follow-ups** — only risks that need a measurement or
   environment unavailable to this review.
4. **Verdict** — ready, ready with stated follow-up, or blocked by a verified
   issue. Do not commit, push, stage, or make remote changes; request explicit
   approval for any write action.

Use `references/legacy-review-playbook.md` only for specialized prompts or
framework checklists; keep the normal review concise and evidence-led.
