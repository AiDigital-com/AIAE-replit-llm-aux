---
name: fullstack-performance-audit
description: Repository-wide performance audit for backend, frontend, database, and delivery paths. Reports only evidence-backed defects and clearly labels measurement risks or missing evidence.
---

<!--
Generated file. Do not edit directly.
Source: AIAE-llm-aux/skills/fullstack-performance-audit/SKILL.md
Revision: 690a9748657adf81d01702dafa2c7ecc8afcf5c5
Target: claude
-->


# Full-stack performance audit

Use for a whole-repository performance review, not merely the current diff.
If the invocation mechanism does not expand `$ARGUMENTS`, treat the user's
latest request as the scope. Default to the whole repository when no narrower
scope is explicitly requested.

## Contract

- Read repository instructions and architecture documents before examining code.
- Do not claim a defect from a suspicious pattern alone. A confirmed finding
  needs an execution path, a cost mechanism, and sufficient static or measured
  evidence.
- Work without runtime metrics. State exactly what cannot be proved without
  profiling, load data, query plans, or production traces.
- Do not limit scope to commits, staged files, or local diffs unless the user
  explicitly requests that limitation.
- Never invent benchmarks, row counts, cache hit rates, or request volumes.

## Method

1. **Map the system.** Identify entry points, request flows, scheduled jobs,
   queues, persistence boundaries, external calls, frontend data fetching,
   bundles, and deployment/runtime constraints.
2. **Trace expensive paths.** For each likely hot path, follow the path from
   trigger through serialization, service calls, queries, external I/O, and UI
   rendering. Inspect call multiplicity, batching, pagination, retries,
   timeouts, payload size, caching, connection usage, and fan-out.
3. **Check each layer.**
   - Backend: blocking work, repeated mapping/serialization, unbounded reads,
     synchronous external calls, retry amplification, resource-pool limits.
   - Database: N+1 query paths, missing/selectivity-mismatched indexes,
     unbounded sorts, lock contention, pagination, transaction scope.
   - Frontend: duplicate requests, waterfall dependencies, cache keys,
     polling, rerender fan-out, list virtualization, bundle and asset loading.
   - Cross-layer: payload amplification, repeated authorization/lookups,
     cache invalidation correctness, API shape, concurrency and backpressure.
4. **Classify evidence.** Use one of these labels:
   - **Verified defect** — code path and costly behavior are demonstrated.
   - **Measurement risk** — a plausible risk whose impact needs runtime data.
   - **Observability gap** — missing metric/log/trace needed to decide.
   - **Non-finding** — suspicious code that is bounded, cached, unreachable,
     or otherwise not proven harmful.
5. **Prioritize.** Rank verified defects by expected user impact, likelihood,
   blast radius, and confidence. Give a smallest safe remediation and a
   verification measurement for each.

## Report

Start with scope, repositories/documents read, and evidence limitations. Then
provide a compact table:

| Priority | Classification | Location/path | Evidence and execution path | Recommendation | Verify with |
|---|---|---|---|---|---|

Follow with:

- a short request/data-flow map;
- measurement risks and observability gaps separately from defects;
- explicit non-findings where that prevents a misleading recommendation;
- a staged remediation plan (quick containment, structural fix, validation).

For deep framework-specific heuristics, consult
`references/legacy-audit-playbook.md` selectively. It is reference material,
not a requirement to emit a giant checklist.

## Completion criteria

Before declaring the audit complete, ensure every verified issue includes a
reproducible code path or measurement, every recommendation preserves the
observed behavior, and all uncertainty is visible to the reader.
