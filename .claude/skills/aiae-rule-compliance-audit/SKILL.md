---
name: aiae-rule-compliance-audit
description: AIAE-specific whole-repository audit against the installed dual-agent engineering contract. Use when a generated AIAE project needs a periodic health check, migration validation, or pre-handoff compliance review.
---

# Rule Compliance Audit

Run a read-only, whole-contract audit. This is broader than code review: it
checks architecture, generated boundaries, configuration, tests, frontend
behavior, documentation, and rule distribution.

## Authoritative source discovery

Load and record every authoritative source that exists:

1. `CLAUDE.md`;
2. `AGENTS.md` when the active Replit surface is present;
3. `replit.md` when the active Replit surface is present;
4. every applicable file under `.claude/rules/`;
5. `.claude/agent_docs/index.md` and the topic documents it routes to.

The engineering-handoff state intentionally removes `AGENTS.md`, `replit.md`,
and `.agents/`; their absence after a completed handoff is not a violation.
Before handoff, a missing or contradictory runtime entry point is a
`RULE_DISTRIBUTION_PROBLEM`.

If neither `CLAUDE.md` nor `AGENTS.md` exists, stop with `STATUS: INCOMPLETE`.
Never substitute remembered template rules for missing repository evidence.

## Procedure

1. Report the exact rule sources loaded and expected sources that were absent.
2. Record the audit scope, current branch/diff state, discovered package root,
   modules, build tools, and test layers. Never substitute template assumptions
   for repository facts.
3. Build a rule-to-evidence matrix before reporting findings:
   - rule and source file;
   - files/commands inspected;
   - compliant, violation, accepted exception, or not verified.
4. Run relevant scanners from the specialized backend/frontend review skills.
   Inspect every hit before classifying it.
5. Check cross-cutting risks scanners miss:
   - business-flow and authorization gaps;
   - generated contract drift;
   - repositories bypassed by orchestration;
   - silent failures and broad fallbacks;
   - missing configuration or secrets committed to source;
   - duplicate frontend requests and stale user-scoped cache;
   - unbounded/detail-heavy APIs, N+1/repository-in-loop work, and in-memory
     filtering/pagination;
   - external I/O inside transactions and unsafe timeout/retry ordering;
   - missing Lombok dependencies in any backend Maven submodule;
   - reusable external metrics duplicated outside `backend/observability`, or a
     third-party Spring HTTP client missing either
     `ExternalClientMetricsInterceptor` or `LogbookClientHttpRequestInterceptor`;
   - missing loading/error/empty/success UI states;
   - build/test/CI commands that no longer match repository structure.
6. Run the strongest practical verification commands. Never infer full
   compliance from a partial build or scanner-only pass.

## Classification

- `VIOLATION`: confirmed conflict with an applicable rule.
- `ACCEPTED_EXCEPTION`: explicit, documented project decision with evidence.
- `NOT_VERIFIED`: required runtime/tool/credential unavailable.
- `COMPLIANT`: inspected evidence satisfies the rule.
- `ARCHITECTURE_CONCERN`: evidence-backed risk not covered by a loaded rule;
  report separately and never label it as non-compliance.
- `RULE_DISTRIBUTION_PROBLEM`: a rule exists but is missing from one runtime,
  unreachable from its entry point, or conflicts with another loaded source.
- `MISSING_RULE_COVERAGE`: an important area has no applicable rule; recommend
  coverage without inventing a violation.

Report only high-confidence violations. Separate pre-existing debt from changes
in the requested scope. Do not turn every recommendation into a compliance
failure.

## Output

```text
STATUS: COMPLIANT | VIOLATIONS_FOUND | INCOMPLETE
Scope: <whole repo or areas>
Rule sources loaded:
- <path> — <CLAUDE | AGENTS | Replit context | rule | agent doc>
Evidence: <commands/files>
Counts: blocking=<n>, important=<n>, minor=<n>, not_verified=<n>
Findings:
- [severity, confidence] rule-source - file:line - violation - impact - fix
Accepted exceptions:
- <decision and evidence>
Architecture concerns (not rule violations):
- <concern and recommendation>
Rule distribution problems:
- <problem and fix>
Missing rule coverage:
- <gap and suggested rule>
Not verified:
- <gap and what is required>
```

`COMPLIANT` is allowed only when all applicable blocking rules have evidence,
the loaded-source list is present, and no unresolved rule-distribution problem
can hide an applicable rule.
