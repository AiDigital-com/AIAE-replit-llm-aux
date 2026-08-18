# Version Control Checkpoints

Long-running work must leave a Git trail while it is produced, not only when it
is finished. Uncommitted work is lost to a context limit, a compaction, a
session reset, a Replit rollback, a failed regeneration, or a cleanup script,
and re-deriving it costs far more than the commits would have.

Version control stays user-owned. The agent never stages, commits, pushes, or
rewrites history on its own initiative. What this document requires is that the
agent **offers a commit at every checkpoint** instead of silently accumulating
hours of uncommitted work until the phase ends.

## When this applies

Offer checkpoint commits for work that cannot be finished in one uninterrupted
stretch:

- a service built from scratch;
- a migration, bulk rename, or refactor spanning many files;
- a multi-phase feature, or any single phase with more than a few steps;
- anything that crosses a session boundary, a context compaction, or a
  regeneration/codegen step.

The trigger is the shape of the work, not the label on the phase. One phase can
be long enough to exhaust the context window several times over, and hitting a
context limit in the middle of a long phase is the most common way hours of
migration work are lost. Phase boundaries are too coarse to protect against it.

For a small bounded change — one reviewable diff, finished in one stretch —
offer a commit once at the end, with the working tree left for the user to
review.

## Relationship to `task-workflow`

`task-workflow` Step 2 tells the developer role not to stage, commit, or push
automatically and to leave version-control actions to the user "unless the user
explicitly requests a commit". This document does not override that rule, it
supplies the missing half: the agent must *ask* at checkpoints, so the user gets
the chance to grant that request while the work still exists. Both rules hold at
the same time — the agent proposes, the user decides.

Read-only review and audit skills (`backend-rule-review`,
`frontend-style-review`, `production-code-review`, `aiae-rule-compliance-audit`,
`fullstack-performance-audit`) never propose commits; they report findings.

## How to offer a checkpoint commit

At each checkpoint, in one short message:

1. State what is finished and now committable.
2. List the exact paths to stage — never a blanket `git add -A`.
3. Propose the subject line in the repository's format:
   `<TASK-ID-or-short-slug> <short imperative description>`. Do not invent a
   ticket prefix the user did not supply.
4. Wait for approval. An approved `git commit` permission prompt is approval;
   silence is not.

If the user declines, continue and keep the checkpoint on the record, then offer
again at the next checkpoint and before any risky step below.

If the user grants standing approval ("commit checkpoints yourself", "don't ask
every time"), that approval holds for the current session's checkpoint commits
only. It never extends to pushing, branching, tagging, or history rewriting.

## Mandatory offer points

- Every completed checkpoint, not only phase, milestone, or workflow-step
  boundaries. A phase commit should close work that smaller commits already
  recorded.
- **Before** any step that can destroy work or consume a large amount of
  context: `strip-scaffold-samples.sh`, `remove-cache-management.sh`,
  `remove-usage-logging.sh`, `apply-package-name.sh`, OpenAPI regeneration,
  dependency upgrades, a broad refactor, or a bulk read/edit sweep across many
  files. Say plainly that the commit is the rollback point.
- When a context limit or compaction is approaching. Offer the commit before
  continuing, so the next context starts from a recorded state instead of
  reconstructing what was in flight.
- Before ending a session, a phase, a review round, or a long verification run
  with uncommitted work.

## What counts as a checkpoint

Any self-contained step whose result later steps build on. For a service built
from scratch that is roughly one commit per line:

1. Scaffold copied and `apply-package-name.sh` applied.
2. OpenAPI YAML for the endpoints the feature needs.
3. Regenerated backend interfaces and frontend types.
4. Liquibase changelog plus entity, repository, and paired entity service.
5. Orchestration service and MapStruct mapper.
6. Controller implementing the generated `*Api` interface.
7. Frontend feature: typed API access, hook, page, route, styles.
8. Tests for the new behavior.
9. Sample-aggregate strip, README, and `docs/architecture-overview.md` updates.

For a migration or bulk refactor, the unit is the migrated slice, not the phase:
one commit per migrated module, aggregate, screen, or batch of files that
compiles on its own. A phase that migrates twenty files offers roughly twenty
checkpoints, not one.

For a feature inside an existing service, the same rule applies at a smaller
scale: contract change, persistence change, service logic, controller, UI,
tests, docs.

## What a proposed checkpoint commit must satisfy

- The touched area compiles. Run the narrow compile/typecheck for the changed
  module rather than the full gate; full test and coverage gates belong to the
  phase or completion commit.
- If a checkpoint falls mid-refactor and does not compile yet, say so and
  propose the subject with a `wip:` prefix, to be resolved before the phase
  commit. A declined `wip:` offer is still better than an unreported gap.
- Report `git status` before proposing, and name explicit paths.
- Never propose secrets, `.env`, service-account JSON, credentials, data dumps,
  `target/`, `dist/`, or `node_modules/`.
- One logical change per commit, and only the change set of the current task —
  never sweep in unrelated edits the user is working on.

## Always explicit, never inferred

Pushing, creating or deleting branches and tags, and history rewriting
(`commit --amend`, `rebase`, `reset --hard`, force push) require an explicit
user request every time. Approval of a checkpoint commit is not approval to
push, and commits that were already pushed are never rewritten.
