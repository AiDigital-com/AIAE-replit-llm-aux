---
name: backend-rule-review
description: Review changed Java/Spring backend code against the installed architecture and compliance rules. Use after backend changes, before commit/PR, or when asked to validate service boundaries, OpenAPI controllers, configuration, typing, JavaDoc, tests, or generated-source safety.
---

# Backend Rule Review

Perform a read-only, evidence-based review. Report real defects and explicit rule
violations, not raw scanner matches.

## Inputs

1. Read `CLAUDE.md`, `.claude/rules/00-backend-hard-rules.md`, and the relevant
   backend docs/rules.
2. Establish scope from the user's files, a commit range, staged/unstaged diff,
   or the whole backend when explicitly requested.
3. Read requirements or a plan when available. Review behavior against intent,
   not only formatting.

## Review sequence

1. Inspect the diff and nearby production code before running scanners.
2. Check correctness, authorization, transactions, concurrency, error handling,
   nullability, persistence semantics, and external-service failure behavior.
3. Check architecture:
   - one entity, one repository, one paired entity service;
   - controllers and orchestrators do not inject repositories;
   - controllers implement generated `*Api` interfaces and stay thin;
   - outbound integrations stay in `backend/external-services`;
   - reusable external metrics stay in `backend/observability` while Logbook
     and inbound application observability stay application-owned;
   - third-party Spring HTTP uses `PooledRestClientFactory` with
     `LogbookClientHttpRequestInterceptor`;
   - database transactions do not span external HTTP/SDK/storage/AI I/O;
   - service/application mappers remain narrow and aggregate-specific.
4. Check compliance:
   - `@ConfigurationProperties`, not `@Value`;
   - no private methods or static utility behavior on production beans;
   - top-level DTOs, records, and enums;
   - JavaDoc on handwritten methods under the installed rule;
   - every Maven submodule declares Lombok and uses it for appropriate boilerplate;
   - business codes use typed enums/constants rather than inline magic values;
   - generated OpenAPI sources are untouched.
5. Check performance amplification using
   `.claude/agent_docs/performance_engineering.md`: bounded collections and
   summary payloads, no repository/lazy access in loops, set-based bulk work,
   no unchanged identity writes, explicit timeouts, and measurement-backed
   cache/pool/index changes.
6. Map changed behavior to existing tests. Report only meaningful regression
   gaps; do not demand tests for trivial generated/Lombok behavior.
7. Run relevant scanners/build/tests when permitted. A scanner hit becomes a
   finding only after source inspection confirms it.

Useful discovery scans:

```bash
grep -rn "@Value" backend/*/src/main/java | grep -v /target/
grep -rnE "^[[:space:]]+(public |protected )?(static )?(record|class|enum) [A-Z]" backend/*/src/main/java | grep -v /target/
grep -rn "Repository" backend/application/src/main/java backend/service/src/main/java 2>/dev/null | grep -v /target/
grep -rnE "static [A-Za-z0-9_<>]+ [a-z][A-Za-z0-9_]*[[:space:]]*\(" backend/service backend/application/src/main/java | grep -v "static final" | grep -v /target/
```

## Finding threshold

Report a finding only when confidence is at least 80/100 and it is introduced or
exposed by the review scope. Label pre-existing issues separately. Do not report
formatter/import-order noise that automation owns.

Severity:

- `BLOCKING`: correctness, security, data loss, broken contract/build, or hard-rule violation.
- `IMPORTANT`: likely regression, architecture erosion, or material missing test coverage.
- `MINOR`: actionable maintainability issue explicitly covered by project rules.

## Output

Lead with findings ordered by severity:

```text
STATUS: PASS | CHANGES_REQUESTED
Scope: <files/range>
Verification: <commands and outcomes, or not run>
Findings:
- [severity, confidence] file:line - problem - impact - concrete fix
Pre-existing/accepted exceptions:
- <only when relevant>
```

If no qualifying findings exist, say so and state remaining verification gaps.
