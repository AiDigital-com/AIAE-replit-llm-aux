# AIAE Templates — engineering reference

Architecture, contracts, and verification for the two-repository template system.
For the non-technical walkthrough see [../user-guide/README.md](../user-guide/README.md).

Generated Java backends include Hibernate L2/query-cache infrastructure and an
active PostgreSQL-backed cross-node invalidation outbox. This is capability,
not a directive to cache every entity. The handoff-safe contract is
`.claude/agent_docs/distributed_cache.md` inside a materialized project.

This document lives in `AIAE-replit-llm-aux`. Paths written as
`AIAE-llm-aux/...` refer to the sibling repository, expected as `../AIAE-llm-aux`
relative to this one — which is also the fallback `sync-llm-aux.sh` resolves.

```text
AIAE-templates/
├── AIAE-llm-aux/          # canonical, vendor-neutral agent skills
└── AIAE-replit-llm-aux/   # the template: scaffold, project rules, generation workflows
    └── docs/
        ├── user-guide/    # step-by-step, no shell commands
        └── engineering/   # this document
```

---

## Key ideas

Six decisions explain almost every file here. The rest follows mechanically.

### 1. Two native registries, one canonical source

Replit Agent discovers `.agents/skills/`; Claude Code discovers
`.claude/skills/`. Common skills are rendered from the exact revision in
`llm-aux.lock` into both surfaces. Their shared `{{TASK_STATE_DIR}}` resolves
to `.claude/tasks`, so agents continue the same plan/review/verification state.

### 2. Project-owned skills are compiled across lifecycle states

`templates/generated-project/**` is the canonical documentation tree in the
template control plane and is removed from generated projects. Skills therefore
have three ownership classes:

| Class | Ships | Source references | Installed references | Example |
|---|---|---|---|---|
| **common generated** | yes | installed project files only | unchanged | `task-workflow` |
| **project-owned payload** | yes | canonical template docs | `.claude/agent_docs/**` | `backend-java-feature`, `mvp-safety-review` |
| **control-plane** | no | template repository | n/a | `project-init` |

`materialize-project.sh` rewrites project-owned skill citations after copying
both registries. `check-payload-portability.sh` validates the active template
state; `verify-gates.sh` validates the installed state and rejects any surviving
control-plane reference.

### 3. Common skills are vendored, and drift is a CI failure

`AIAE-llm-aux` is the source of truth for reusable skills. They are **generated
into and committed** to the template rather than fetched at runtime, because a
downloaded project must work with no second checkout.

The price of committing generated files is silent divergence.
`test-sync-drift.sh` re-renders from the pinned revision and fails on any
difference. That check is what makes vendoring safe.

### 4. Integrity is content-addressed

`llm-aux.lock` pins an exact SHA. `repository` is only a *preferred* source: sync
extracts that exact commit and refuses if it is unreachable. Any source producing
that commit is fine — remote, sibling checkout, mirror.

The local cache is a **bare** mirror and the pinned tree is extracted with
`git archive` into a temp dir. Nothing is ever checked out, so a cache left dirty
or pointing at a commit that upstream later rewrote cannot wedge sync.

Resolution: `$LLM_AUX_SOURCE` → sibling `../AIAE-llm-aux` → lock URL. Rollback is
one edit: set `revision` to the previous SHA and re-run sync.

### 5. Coverage is phased, and the final gate is not skippable

Business first, but the debt gets paid. The phase is a committed property of the
project in `.template-phase`:

| Phase | Line | Branch | When |
|---|---|---|---|
| `mvp` | 0.30 | 0.25 | while the product is being discovered |
| `engineering` (pom default) | 0.80 | 0.70 | from finalization onward |

Three properties make this hold:

- **Strict is the default.** The 0.80/0.70 values are the pom defaults, so a bare
  `mvn verify` is always strict. Relaxation requires `-Pmvp`, passed only while
  `.template-phase` reads `mvp`. Forgetting a flag can never weaken the gate.
- **The phase is committed, not detected.** Keying it off the runtime (Replit vs
  local, which agent is driving) would mean the same commit passes in one place
  and fails in another; env vars are absent in CI and forgeable by an agent
  chasing a green build; and there would be no record of when coverage was
  relaxed. A file gives one answer per commit and shows up in review.
- **The floor is never zero.** A 0.00 gate lets coverage start at nothing and
  turns finalization into one large batch of test-writing.

`prepare-engineering-handoff.sh` refuses to run while the phase is `mvp`, and the
phase cannot regress from `engineering` back to `mvp`.

### 6. Destructive and generated operations are explicit

- Handoff is **dry-run by default** (`--apply` to act) and always refuses a
  dirty Git tree; there is no bypass flag.
- The renderer deletes everything under `--output` it did not generate, so it
  **refuses** to run against a directory holding a hand-written skill.
- Sync deletes only what its target-specific managed manifests say it created —
  never by grepping file contents for a marker string.
- `check-coverage-integrity.sh` rejects lowered thresholds, skip flags on any
  verification surface, `<exclude>` entries covering hand-written code, and phase
  regressions. It cannot make bypass impossible — anyone who can edit a pom can
  edit a number — but it makes every bypass a visible, reviewable change instead
  of an invisible flag.

### 7. Context7 configuration ships; credentials do not

The template and every generated project commit a project-level `.mcp.json`
pointing to Context7's remote OAuth endpoint. Claude Code can therefore discover
the MCP consistently while each developer owns approval and authentication.

Replit Agent MCP integrations are account-level and cannot be provisioned by
project files. The user guide and root README carry a one-click Replit install
link. No Context7 API key belongs in the repository, `.env.example`, agent chat,
or generated artifact.

---

## The flow

### Creating a project

Two entry points, one self-contained result.

```bash
cd AIAE-replit-llm-aux
bash scripts/new-project.sh ~/work/my-app myapp --claude-only
```

Or in conversation, for non-technical users: open the template with Claude Code
and say *"do initialize project"* — the `project-init` skill drives the same
script.

**From Replit:** fork the template; `.replit` `onBoot` runs `setup-project.sh`
and the Replit Agent materializes the scaffold per `custom_instruction/`.

Then, in the project:

```bash
bash scripts/strip-scaffold-samples.sh
bash scripts/local-verify.sh
docker compose --profile local up --build
```

### What a generated project contains

```text
backend/ frontend/ scripts/     the app (package com.aidigital.<name>.*)
CLAUDE.md                       Claude Code entry point
.claude/rules/                  auto-loaded project rules
.claude/agent_docs/             reference documentation
.claude/skills/                 the 15 payload skills
.claude/tasks/                  task artifacts
.mcp.json                       Context7 remote MCP endpoint; no credential
.template-phase                 coverage phase — starts at `mvp`
AGENTS.md replit.md             Replit entry points (omitted with --claude-only)
```

### Changing a common skill

```bash
# in AIAE-llm-aux
vim skills/task-workflow/SKILL.md.template
bash scripts/validate-skills.sh && git commit -am "improve task-workflow"

# in AIAE-replit-llm-aux
bash scripts/sync-llm-aux.sh --update-lock
bash scripts/sync-llm-aux.sh
git add llm-aux.lock .claude/.llm-aux-manifest .agents/.llm-aux-manifest .claude/skills .agents/skills
```

Commit the lock and regenerated files together or the drift check fails.

### Adding a skill

Reusable across projects → `AIAE-llm-aux/skills/<name>/SKILL.md`, add the name to
`.llm-aux-managed-skills`, sync.

Template-specific → `AIAE-replit-llm-aux/.claude/skills/<name>/SKILL.md`. Then
decide whether it ships: if yes, add it to `agent-payload.skills` and keep its
references inside `CLAUDE.md` / `.claude/**`. The portability check will tell you
if you missed one.

Use `SKILL.md.template` only when a value genuinely differs per consumer.

### Finalizing and handing off

```bash
# raise coverage to 0.80/0.70 — the finalize-coverage skill drives this
mvn -f backend/pom.xml -B clean verify     # no -Pmvp: the real gate
echo engineering > .template-phase
bash scripts/local-verify.sh

bash scripts/prepare-engineering-handoff.sh            # dry run
bash scripts/prepare-engineering-handoff.sh --apply
```

Removes `AGENTS.md`, `replit.md`, `custom_instruction/`, `templates/`. Preserves
`CLAUDE.md` and all of `.claude/`.

---

## Downloading a project from Replit

It works with no extra setup, because `.claude/` is committed by design.

The app materializes at the Replit **workspace root**, so both runtime surfaces
sit beside `backend/` and `frontend/` and travel with any download or clone.
The scaffold's `.gitignore` excludes only template-source paths such as
`templates/` and `custom_instruction/`. It deliberately keeps `AGENTS.md`,
`replit.md`, `.agents/`, `CLAUDE.md`, and `.claude/` tracked; setup does not
untrack those active project files.

Requirements:

1. Open the directory containing `backend/`, `frontend/`, and `CLAUDE.md`. Claude
   Code resolves `.claude/` from the opened root, so opening a subdirectory finds
   nothing.
2. Keep `.claude/` in version control.

Only payload skills are present — control-plane skills are absent by design,
since their `templates/**` references would be dangling. That absence is what
`check-payload-portability.sh` guarantees is harmless.

---

## Verification

| Command | Repo | Checks |
|---|---|---|
| `scripts/validate-skills.sh` | llm-aux | frontmatter, naming, uniqueness |
| `tests/test-render-skills.sh` | llm-aux | renderer behavior |
| `scripts/check-payload-portability.sh` | replit | dual registries + shipped-skill contract |
| `scripts/sync-llm-aux.sh --check` | replit | generated skills match the lock |
| `scripts/test-sync-drift.sh` | replit | the above, plus clean tree |
| `.../test-materialize-project.sh` | replit | materialization + handoff |
| `.../lib/check-coverage-integrity.sh` | project | coverage gate not tampered with |
| `scripts/test-release-replit-template.sh` | replit | flattened release artifact |

Both repositories run these in CI. `.sh` discovery is by extension, not
executable bit, so a missing `+x` cannot silently drop a script.

File lists inside the scanners are built with `find`, not `grep --include`:
`grep` may be ugrep on developer machines, whose `--include` semantics differ,
and a scanner that silently widens its own scope is worse than no scanner.

---

## Where things live

| Question | Answer |
|---|---|
| Authoritative version of a common skill | `AIAE-llm-aux/skills/` |
| Which common revision is in use | `AIAE-replit-llm-aux/llm-aux.lock` |
| Which common skills are installed | `.llm-aux-managed-skills` (intent) / target manifests (actual) |
| Which skills ship into projects | `agent-payload.skills` |
| Rules applying to generated code | `.claude/rules/` |
| Coverage phase of a project | `.template-phase` |
| Why two registries and one task store | `AIAE-replit-llm-aux/docs/agents-lifecycle-decision.md` |
| How to consume llm-aux from a new repo | `AIAE-llm-aux/docs/repository-integration.md` |

## Validation status

- **`fullstack-performance-audit` is canonical but still needs additional
  real-world validation.** See `AIAE-llm-aux/docs/validation-status.md`.
- `llm-aux.lock` records the exact canonical source revision. Publish the
  common-repository commit before pushing a Replit-template commit that pins it,
  otherwise remote CI cannot fetch that SHA.
