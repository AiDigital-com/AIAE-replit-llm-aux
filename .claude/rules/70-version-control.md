---
description: Checkpoint commit offers during long feature, migration, and from-scratch service work.
paths:
  - "backend/**/*"
  - "frontend/**/*"
  - "docs/**/*"
  - "README.md"
---

# Version Control Rules

- Version control is user-owned: never stage, commit, push, or rewrite history
  on your own initiative. Pushing, branching, tagging, `amend`, `rebase`,
  `reset --hard`, and force push need an explicit user request every time.
- Offer a commit at every completed checkpoint, not only at phase or milestone
  boundaries, when the work is a from-scratch service, a migration or bulk
  refactor, a multi-phase feature, or any phase longer than a few steps.
- Checkpoints are self-contained steps later steps build on: OpenAPI change,
  regenerated sources, migration plus entity/repository/entity service,
  orchestration service and mapper, controller, frontend feature, tests, docs.
  In a migration the unit is the migrated slice, not the phase.
- Offer a commit before any destructive, regenerating, or context-heavy step
  (`strip-scaffold-samples.sh`, `remove-cache-management.sh`,
  `remove-usage-logging.sh`, `apply-package-name.sh`, codegen, broad refactor),
  when a context limit is approaching, and before ending a session or phase.
- When offering: report `git status`, name explicit paths (never `git add -A`),
  propose the subject, and wait for approval. Never propose secrets, `.env`,
  credentials, `target/`, `dist/`, `node_modules/`.
- The touched area must compile; propose a `wip:` subject if a mid-refactor
  checkpoint cannot compile yet, to be resolved before the phase commit.
- Full policy: `.claude/agent_docs/version-control-checkpoints.md`.
