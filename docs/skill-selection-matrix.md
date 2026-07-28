# Skill selection matrix

Fourteen skills ship into every generated project. Claude Code also has a
template-only `project-init` skill. Replit initialization is governed by the
always-loaded `AGENTS.md`, `replit.md`, and `custom_instruction/` contract
instead, so `.agents/skills` intentionally has no `project-init`.

Replit reads each skill's frontmatter to judge relevance and loads the body only
when it fires; Claude Code selects on the description alone. Neither can be
steered at runtime, so the description *is* the routing logic.

`scripts/check-skill-selection.sh` fails identical trigger clauses and reports
near-duplicate vocabulary for review. Vocabulary similarity is advisory: it
cannot tell whether the intended skill actually wins. **Verify routing by hand
after changing any description**, using fresh Replit and Claude sessions in a
materialized project.

This is a review checklist, not an automated test. There is no supported way to
assert an agent's private selection decision, so treating it as CI-enforced would
be a false claim.

## Expected routing

| # | What the user says | Expected skill |
|---|---|---|
| 1 | "create a new project called Margin Tool" | Claude: `project-init`; Replit: always-loaded template instructions |
| 2 | "describe the API contract for reports before we build it" | `openapi-contract-first` |
| 3 | "add an endpoint that accepts a CSV upload" | `backend-java-feature` |
| 4 | "build a page listing deals with a filter bar" | `frontend-react-feature` |
| 5 | "check my backend changes before I commit" | `backend-rule-review` |
| 6 | "review the CSS and markup I just wrote" | `frontend-style-review` |
| 7 | "tidy up this screen, make it match the design system" | `ui-designer` |
| 8 | "the deal list is slow with 5000 rows" | `fullstack-performance-audit` |
| 9 | "do a full review of my changes before the PR" | `production-code-review` |
| 10 | "does this project follow our engineering rules?" | `aiae-rule-compliance-audit` |
| 11 | "I want to demo this to a stakeholder tomorrow" | `mvp-safety-review` |
| 12 | "the project is finished, finish the tests" | `finalize-coverage` |
| 13 | "we are handing this over to the engineering team" | `engineering-handoff` |
| 14 | "big change — plan it, implement it, then review it" | `task-workflow` |
| 15 | "you said the tests pass; prove it" | `verification-gate` |

Rows 2-15 are the shipped payload and each appears exactly once. Row 1 is a
Claude template skill and a Replit instruction route, not a generated-project
skill. A skill that cannot be reached by any plausible sentence does not belong
in `agent-payload.skills`.

## Known adjacencies

These pairs are close by design. Re-check them whenever a description changes:
the vocabulary report can draw attention to similarity but cannot validate
runtime behavior.

**2 vs 3 — contract before implementation.** "Add an endpoint" is legitimately
both. `openapi-contract-first` owns the case where the contract does not exist
yet; `backend-java-feature` assumes it does and implements against the generated
interface. If the wrong one fires the result is still workable, only out of order.

**6 vs 7 — correctness versus polish.** `frontend-style-review` gates a diff
against installed frontend rules. `ui-designer` changes appearance on purpose.
Firing `ui-designer` during a parity task is the harmful direction: it redesigns
what the user asked to preserve.

**5, 6 vs 9 — scope.** `production-code-review` is whole-diff and cross-layer;
the two rule reviews are single-domain gates. Overlap is acceptable because all
three are read-only and produce findings rather than edits.

**11, 12, 13 — the handoff chain, and the only ordering that matters.**
`mvp-safety-review` gates a demo. `finalize-coverage` raises coverage and flips
`.template-phase` from `mvp` to `engineering`. `engineering-handoff` strips the
Replit control plane and is *refused* by `prepare-engineering-handoff.sh` while
the phase is still `mvp`. So a user who says "we're handing over" without having
finalized coverage is stopped by the script, not by skill selection — the gate
holds even if routing picks the wrong one of the three.

## When this table changes

Adding a skill means adding a row. If a new skill cannot be given a sentence that
no existing row already claims, its trigger space is taken: narrow it, or ship one
of the two rather than both. That is why the generic `rule-compliance-audit`
was removed from this payload: its trigger clause was word-for-word identical
to `aiae-rule-compliance-audit`, so no agent could choose reliably. The retained
AIAE skill includes the generic skill's source-discovery and finding
classifications plus project-specific checks.
