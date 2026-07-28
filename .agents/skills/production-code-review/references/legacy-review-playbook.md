---
name: production-code-review
description: Verified production-readiness review of local changes, the latest branch commit, or explicitly supplied commits
---

Perform a thorough production code review for: **$ARGUMENTS**

## Arguments

Use the following format:

```text
<mandatory task context> [| commits: <SHA(s) or range>] [| issue: <Jira or issue URL>] [| stack: <technology context>]
```

Examples:

```text
Add cleanup of denormalized category views by bucket ID. Group and SKU data must not be deleted by age.
```

```text
Add cleanup of denormalized category views by bucket ID. Group and SKU data must not be deleted by age. | commits: abc1234 def5678
```

```text
Introduce an idempotent cleanup scheduler. Retries must not delete current-generation records and cleanup must be observable. | issue: https://jira.example.com/browse/CAT-123 | stack: Java 21, Spring Boot 3, Cassandra
```

The **task context is mandatory**. It must explain enough expected behavior, constraints, or acceptance criteria to judge whether the implementation is correct.

A commit reference and an issue URL are optional.

An issue URL alone does not replace the mandatory task context unless the user also provides a concise description of the expected change.

Parse optional sections by their prefixes:

- `commits:` — optional commit SHA, list of SHAs, or commit range
- `issue:` — optional Jira or issue URL
- `stack:` — optional stack information or additional technical context
- text before the first prefixed optional section — mandatory task context

If the mandatory task context is missing or is too vague to establish the expected behavior, stop and ask the user to provide it before reviewing the code.

Do not modify production code unless the user explicitly asks for fixes. The primary output of this skill is a verified review report.

## Review objective

Act as a senior software engineer reviewing a production-ready pull request.

Review the **final cumulative state** of the selected change. Do not treat intermediate commits as independently deployable states.

When explicit commits are supplied, call out when a verified problem was introduced or left unresolved by a specific commit.

Only report findings verified by reading the code, configuration, schema, tests, Git state, or build output. Do not report speculative issues, generic recommendations, or stylistic preferences as defects.

## Step 1 — Determine what to review

Use the following precedence.

### 1. Explicit commits

When `commits:` is supplied:

- resolve the supplied SHA, SHA list, or commit range
- identify the oldest and newest reviewed commits
- determine the parent or merge base representing the state before the change
- review the final cumulative diff
- inspect the final version of every affected file

For a linear commit sequence, review the equivalent of:

```bash
git diff <parent-of-oldest-commit>..<newest-commit>
```

For a commit range, verify the actual boundaries before reviewing it.

For merge commits or non-linear history, determine an appropriate merge base and state the selected comparison range in the report.

### 2. Local working-tree changes

When `commits:` is not supplied, inspect the repository state:

```bash
git status --short
```

If there are local changes, review the complete final working-tree state against `HEAD`.

Include:

- unstaged tracked changes
- staged changes
- newly added untracked files relevant to the change
- deletions
- renames

Use the equivalent of:

```bash
git diff HEAD
git ls-files --others --exclude-standard
```

Do not review only `git diff` if untracked files exist.

The review target is the cumulative state that would be committed if the current local work were finalized.

### 3. Latest commit on the current branch

If `commits:` is not supplied and the working tree is clean, review the latest commit on the current branch:

```bash
git diff HEAD^..HEAD
```

Verify that `HEAD` has a parent. For an initial/root commit, review the commit against the empty tree.

State clearly in the report whether the review covered:

- explicit commits
- local working-tree changes
- or the latest branch commit

## Step 2 — Establish expected behavior

Use the mandatory task context as the primary source of truth.

Extract:

- problem statement
- expected behavior
- acceptance criteria
- explicit constraints
- non-goals
- compatibility expectations
- migration or rollout expectations
- performance and operational requirements

When an `issue:` URL is supplied, read it and use it as supplementary context.

Compare the issue with the mandatory task context and flag contradictions or missing information.

Evaluate whether the implementation:

- satisfies the stated behavior
- misses required behavior
- violates a constraint
- introduces unrelated behavior
- contains out-of-scope refactoring or schema changes
- conflicts with compatibility or rollout expectations

If the issue cannot be accessed, state that clearly. Do not invent its contents. Continue using the mandatory task context.

## Step 3 — Identify the stack and repository rules

Use `stack:` when supplied.

Otherwise, identify the stack from repository files such as:

- `pom.xml`
- `build.gradle`
- `package.json`
- framework configuration
- database configuration
- schema migrations
- Docker files
- CI configuration
- existing tests

Apply the established idioms and conventions of the actual repository rather than generic preferences.

Read repository-local guidance when present, including files such as:

- `CLAUDE.md`
- `AGENTS.md`
- `CONTRIBUTING.md`
- architecture documentation
- code-style configuration
- module-specific README files

Repository rules do not override correctness, security, or data-safety requirements, but they should be considered when evaluating design consistency.

## Step 4 — Inspect the full implementation context

Do not limit inspection to changed lines.

Read enough surrounding code to understand:

- callers and consumers
- public interfaces and implementations
- configuration
- transaction boundaries
- persistence mappings and queries
- related writers and readers
- serializers and API contracts
- error-handling paths
- tests
- database migrations
- scheduled and asynchronous execution
- existing repository conventions

Use `git show`, `git diff`, `git log`, `git blame`, and repository search where useful.

## Part 1 — Correctness and production-readiness

Assess the following areas.

### Correctness

Check for:

- incorrect conditions or branching
- wrong assumptions about input or stored data
- inconsistent writer and reader behavior
- broken state transitions
- off-by-one errors
- incorrect equality or ordering
- partial updates
- stale-data behavior
- incorrect defaults
- invalid lifecycle assumptions

### Edge cases and failure scenarios

Check:

- empty inputs
- null or missing values
- duplicates
- retries
- partial failures
- malformed external responses
- timeouts
- process restarts
- unexpected ordering
- large inputs
- concurrent modifications
- missing dependent records
- cleanup after failure

### Thread safety and concurrency

Check:

- shared mutable state
- race conditions
- check-then-act sequences
- unsafe caches
- transaction isolation assumptions
- lost updates
- duplicate processing
- lock scope
- ordering guarantees
- scheduler overlap
- idempotency under retries

### Performance and scalability

Check:

- unbounded data materialization
- excessive batch sizes
- N+1 queries
- full scans
- missing pagination or limits
- expensive work inside loops
- repeated remote calls
- equivalent duplicate requests
- inefficient cache invalidation
- hot partitions
- excessive tombstones
- blocking work on constrained executors

Do not report a performance issue merely because code could theoretically be faster. Identify the concrete execution path and likely impact.

### Security

Check:

- authorization bypasses
- missing ownership checks
- injection risks
- unsafe deserialization
- secret exposure
- sensitive logging
- insecure defaults
- path traversal
- SSRF
- unsafe redirects
- insufficient validation
- privilege escalation
- improper trust of client-supplied fields

### Error handling and observability

Check:

- swallowed exceptions
- failures converted into successful results
- overly broad catches
- missing retry boundaries
- missing context in logs
- duplicate noisy logging
- sensitive data in logs
- incorrect log levels
- missing metrics for operationally important paths
- failures that cannot be diagnosed in production

### API design and backward compatibility

Check:

- request and response compatibility
- removed or renamed fields
- changed nullability
- enum compatibility
- status-code changes
- serialization changes
- default behavior
- versioning expectations
- generated contract consistency
- compatibility with existing clients

### Data layer

Inspect both writers and readers.

Check:

- schema and primary-key design
- partition-key and clustering-key compatibility
- index usage assumptions
- full scans or filtering
- `ALLOW FILTERING`
- unbounded partitions
- tombstone generation
- TTL behavior
- batch semantics
- conditional writes
- idempotency of writes and retries
- key normalization consistency
- migration safety
- rollback behavior
- uniqueness assumptions
- transaction boundaries
- deterministic result ordering
- cleanup and retention behavior

For Cassandra or similar distributed stores, explicitly assess:

- partition size
- hot partitions
- query compatibility with the primary key
- logged versus unlogged batches
- cross-partition batches
- tombstone accumulation
- TTL interaction with denormalized data
- consistency-level assumptions
- retry safety

### Tests

Check:

- coverage of changed behavior
- meaningful assertions
- missing failure-path tests
- missing boundary tests
- false-positive tests
- mocks that bypass changed logic
- tests coupled only to implementation details
- concurrency and retry cases when relevant
- repository tests for custom queries
- migration tests where supported
- compatibility tests for API changes

### Static analysis and concrete code smells

Check verified concerns likely to be reported by tools such as SonarQube, SpotBugs, Error Prone, Checkstyle, ESLint, or TypeScript.

Do not present formatting preferences as production defects.

## Part 2 — Design, SOLID, and future maintainability

Keep design findings separate from correctness findings.

Assess:

- SRP violations, god classes, and excessive constructor dependencies
- OCP violations and scattered type-based branching
- ISP violations, no-op implementations, and unsupported interface methods
- DIP violations, concrete infrastructure dependencies, and static global access
- duplicated business rules and normalization logic
- primitive obsession, maps, tuples, and scattered magic strings
- ambiguous null-as-signal conventions
- inconsistent naming, static/instance usage, and method contracts
- hidden dependencies and low testability
- direct access to time, randomness, environment, or external clients
- side effects mixed with computation

Prioritize high-leverage refactors that reduce risk for likely follow-up work.

State which refactors should be completed before planned follow-up development.

## Step 5 — Verify every finding

Before reporting a finding:

1. Read the complete affected method or configuration section.
2. Inspect relevant callers and consumers.
3. Inspect related writers and readers.
4. Inspect relevant tests.
5. Confirm the behavior in the final selected state.
6. Check whether framework or database behavior invalidates the concern.
7. Check whether an existing guard, constraint, transaction, or validation already prevents it.
8. Identify the exact affected file, method, and final-state line range.
9. When attributing the issue to a commit, verify the attribution using Git history.

Do not report a finding when the evidence is insufficient.

When useful and safe, run targeted verification such as:

- compilation
- unit tests
- repository tests
- static analysis
- type checking
- focused build commands

Do not claim that a command passed unless it was actually run successfully.

Distinguish unrelated pre-existing build failures from failures caused by the reviewed change.

## Severity definitions

### Critical

Likely to cause:

- severe security compromise
- irreversible or widespread data corruption
- major production outage
- violation of a critical transactional or consistency guarantee

### High

Likely to cause:

- incorrect core business behavior
- significant data inconsistency
- repeated production failures
- major performance degradation
- broken backward compatibility
- authorization bypass or sensitive-data exposure

### Medium

A meaningful production or maintenance issue that:

- affects a narrower scenario
- has a practical workaround
- creates material operational risk
- significantly increases the risk of upcoming work

### Low

A verified issue with limited immediate impact, such as:

- localized maintainability debt
- incomplete diagnostics
- a minor but concrete contract inconsistency
- missing low-risk test coverage

Do not inflate severity to emphasize a recommendation.

## Finding format

For every finding, use:

```md
### [High] Short actionable title

**Affected code:** `path/to/File.java`, `methodName`, lines 120-145  
**Introduced by:** `<commit SHA>` or `Local working-tree change`, when verifiable

**Problem**

Explain the verified behavior and the concrete impact.

**Fix**

Provide a specific correction, design change, query change, or focused code example.

**Verification**

Explain what code paths, callers, tests, or commands confirmed the finding.
```

Use final-state line numbers. If line numbers are unstable because the target is an uncommitted working tree, still provide the current local line range.

## Rules

- Report only verified findings.
- Avoid false positives.
- Do not summarize what the code does.
- Do not provide generic praise.
- Do not present stylistic preferences as defects.
- Prefer a smaller number of high-confidence findings over a large speculative list.
- A short `Verified non-issues` section is allowed when it prevents known concerns from being repeatedly raised.
- Explicitly state when no actionable findings were verified.
- Do not change files during the review unless the user explicitly requests fixes.

## Final report

Write the report in this structure:

```md
# Production Code Review

## Review Scope
- Source: Explicit commits / Local working-tree changes / Latest branch commit
- Compared state: ...
- Task context: ...
- Reference issue: ...
- Stack: ...
- Files reviewed: ...

## Blocking Issues

### [Severity] Finding
...

OR:

No blocking issues verified.

## Non-Blocking Improvements

### [Severity] Finding
...

OR:

No non-blocking issues verified.

## Design and Follow-Up Risks
- Highest-leverage refactors
- Refactors required before planned follow-up work

## Missing or Insufficient Tests
- Concrete missing scenarios

OR:

No material test gaps verified.

## Verified Non-Issues
- Optional short list

## Verification Performed
- Commands run
- Tests run
- Relevant limitations

## Production-Readiness Verdict

**Verdict:** READY / READY WITH NON-BLOCKING IMPROVEMENTS / NOT READY

**Must be fixed before merge:**
1. ...
2. ...

**Top priorities:**
1. ...
2. ...
3. ...
```

The verdict must follow from the verified findings:

- `READY` — no blocking issues or material production-readiness gaps
- `READY WITH NON-BLOCKING IMPROVEMENTS` — only verified non-blocking issues remain
- `NOT READY` — one or more blocking issues remain
