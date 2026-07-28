---
name: verification-gate
description: Verify implementation claims with fresh, scope-appropriate evidence before declaring work complete, fixed, passing, ready to commit, or ready for PR. Use at the end of ad-hoc work and before handoff; use GSD verify-work instead when operating inside a GSD phase.
---

<!--
Generated file. Do not edit directly.
Source: AIAE-llm-aux/skills/verification-gate/SKILL.md
Revision: d8f00e9689669785367c31e97fc5ed2229e7eb0d
Target: agents
-->


# Verification Gate

Require evidence before completion claims.

## Gate

1. Re-read the request, accepted plan, and latest user corrections.
2. Inspect the final diff and repository status. Separate task changes from
   pre-existing work and detect missing/untracked files.
3. Build a claim-to-evidence checklist. For each claimed behavior identify the
   command, runtime interaction, screenshot, contract check, or source inspection
   that can actually prove it.
4. Run fresh verification at the strongest applicable level:
   - focused tests for changed behavior;
   - typecheck/compile;
   - full affected-module tests;
   - build and static gates;
   - browser/API smoke test for user-visible or integration behavior.
5. Read full outputs and exit codes. Do not substitute lint for compile, compile
   for tests, or tests for the original user-visible symptom.
6. Reproduce the original bug/flow when possible. A code diff alone is not proof.
7. Report verified claims, failures, skipped checks, and residual risks. Never use
   `should pass` or imply success when evidence is missing.

For a regression test, verify red/green when practical: demonstrate failure
without the fix and success with it. Do not destructively alter user work to do so.

## Output

```text
STATUS: VERIFIED | FAILED | PARTIALLY_VERIFIED
Claims and evidence:
- <claim> - <command/check> - <result>
Failures:
- <actual failure and next action>
Not verified:
- <gap and reason>
Repository state:
- <task changes vs pre-existing changes>
```

Only `VERIFIED` permits an unqualified completion claim.
