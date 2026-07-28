# AIAE-replit-llm-aux

Template control plane and generated-project scaffold for near-production MVPs
(Java 21 / Spring Boot 3 backend, React + TypeScript frontend).

This repository is **not a runnable app**. It generates projects. Two entry
points create one from it — Replit, or Claude Code locally.

## Getting started

Most users clone only this repository. You do **not** need a separate
`AIAE-llm-aux` checkout: the common skills are pinned and committed here, and
every generated project receives its own working copies.

### Start with Claude Code

1. Clone the template:

   ```bash
   git clone https://github.com/AiDigital-com/AIAE-replit-llm-aux.git
   cd AIAE-replit-llm-aux
   ```

2. Open the template in Claude Code:

   ```bash
   claude
   ```

3. Tell Claude what to create:

   > Initialize a new project called Margin Tool in `~/work/margin-tool`. I
   > will work locally without Replit.

4. When Claude finishes, close that session and open the **new project
   directory** in Claude Code:

   ```bash
   cd ~/work/margin-tool
   claude
   ```

5. Describe the first user outcome in plain language, for example:

   > Build a page where a manager uploads a spreadsheet and reviews rows below
   > the target margin.

Claude creates the project, removes scaffold samples, runs its initial
verification, and tells you if any local prerequisite is missing.

### Start with Replit Agent

1. Open
   [`AiDigital-com/AIAE-replit-llm-aux`](https://github.com/AiDigital-com/AIAE-replit-llm-aux)
   and import it into Replit.
2. Wait for the workspace setup hook to finish.
3. Open Replit Agent and say:

   > Initialize this template as a project called Margin Tool, then build a
   > page where a manager uploads a spreadsheet and reviews rows below the
   > target margin.

4. Enable Replit-managed Clerk Auth when the Agent asks for authentication,
   and put credentials only in Replit Secrets.
5. Optionally connect Context7 through the Replit Integrations link documented
   below.
6. Ask the Agent to run the full verification, then use **Run** to inspect the
   application.

### Technical shortcut

Developers may create the project directly without an interactive setup
conversation:

```bash
git clone https://github.com/AiDigital-com/AIAE-replit-llm-aux.git
cd AIAE-replit-llm-aux
bash scripts/new-project.sh ../margin-tool margintool --claude-only
cd ../margin-tool
claude
```

Use lowercase letters and digits for the package suffix (`margintool` above).
Omit `--claude-only` when the generated project must also retain its Replit
Agent surface.

### Maintainers: working with both repositories

Clone both repositories as siblings only when changing common skills:

```bash
mkdir AIAE && cd AIAE
git clone https://github.com/AiDigital-com/AIAE-llm-aux.git
git clone https://github.com/AiDigital-com/AIAE-replit-llm-aux.git
```

1. Make the common-skill change in `AIAE-llm-aux`.
2. Run `bash scripts/validate-skills.sh` and
   `bash tests/test-render-skills.sh`.
3. Commit and push `AIAE-llm-aux` first.
4. In `AIAE-replit-llm-aux`, run:

   ```bash
   bash scripts/sync-llm-aux.sh --update-lock
   bash scripts/sync-llm-aux.sh
   bash scripts/test-sync-drift.sh
   ```

5. Review and commit the lock, both managed manifests, and both generated skill
   registries together.
6. Push `AIAE-replit-llm-aux` only after the pinned common commit is available
   from GitHub.

## Which guide do you want?

**→ [docs/user-guide/README.md](docs/user-guide/README.md)** — building a project
step by step, in plain language, for the Claude desktop app or the VS Code
extension. No shell commands.

**→ [docs/engineering/README.md](docs/engineering/README.md)** — architecture,
the payload contract, coverage phases, sync and drift detection, verification.

The rest of this file is the repository reference.

## Repository layout

```text
custom_instruction/instructions.md   # authoritative generation rules
replit.md                            # project preferences + deployment model
.replit / replit.nix                 # Replit workspace config
AGENTS.md                            # Replit Agent entry point
CLAUDE.md                            # Claude Code entry point
.mcp.json                            # secret-free project Context7 MCP endpoint

.agents/skills/                      # Replit Agent discovery registry
.claude/skills/                      # Claude Code discovery registry
.claude/rules/                       # auto-loaded project rules
.claude/agent_docs/                  # reference documentation
.claude/tasks/                       # task artifacts (plan, review, verification)

agent-payload.skills                 # which skills ship into generated projects
llm-aux.lock                         # pinned AIAE-llm-aux revision
.llm-aux-managed-skills              # which common skills to install
.claude/.llm-aux-manifest            # generated Claude manifest
.agents/.llm-aux-manifest            # generated Replit manifest

templates/generated-project/         # canonical scaffold + artifacts
scripts/                             # create, sync, release, verification
docs/user-guide/                     # non-technical walkthrough
docs/engineering/                    # architecture and contracts
```

## Dual native skill registries

Replit Agent discovers `.agents/skills/`; Claude Code discovers
`.claude/skills/`. Common skills are generated into both from one exact pinned
revision. Both copies use `.claude/tasks`, preserving shared workflow state.

Skills split by **whether they survive handoff**, declared in
`agent-payload.skills` and materialization define three classes:

| Class | Ships? | May reference | Examples |
|---|---|---|---|
| common generated | yes, to both registries | installed project files only | `task-workflow`, `verification-gate` |
| project-owned payload | yes, compiled into both registries | canonical template docs in source; installed docs after materialization | `backend-java-feature`, `engineering-handoff` |
| control-plane | no | template repository only | `project-init` |

Project-owned payload skills are active before and after materialization.
Materialization rewrites their canonical `templates/generated-project/**`
citations to `.claude/agent_docs/**`; installed checks fail if any control-plane
path survives. `scripts/check-payload-portability.sh` validates the source
state, and generated-project verification validates the installed state.

## Creating a project

**From Claude Code / locally** — no Replit involved:

```bash
bash scripts/new-project.sh ~/work/my-app myapp --claude-only
```

**From Replit** — fork the template; `.replit` `onBoot` runs `setup-project.sh`,
and the Replit Agent materializes the scaffold per `custom_instruction/`.

Either way the result is self-contained: it carries its own `CLAUDE.md`,
`.claude/rules`, `.claude/agent_docs`, and payload skills, and never needs this
template checkout again.

Generated Java projects include an opt-in Hibernate L2/query-cache baseline and
an active PostgreSQL-backed cross-node invalidation outbox. Caching is not
blanket-enabled on application entities: engineers add explicit regions,
registry mappings, and transactional publication only where measurements
justify caching. The complete handoff-safe contract is
`.claude/agent_docs/distributed_cache.md` inside each generated project.

## Current library documentation with Context7

Generated projects include a secret-free project `.mcp.json` for Context7.
Claude Code asks each developer to approve the server and complete OAuth the
first time it is used; no API key is committed or pasted into agent chat.

Replit Agent MCP connections are account-level. Connect Context7 once using
[Add Context7 to Replit](https://replit.com/integrations?mcp=eyJkaXNwbGF5TmFtZSI6IkNvbnRleHQ3IiwiYmFzZVVybCI6Imh0dHBzOi8vbWNwLmNvbnRleHQ3LmNvbS9tY3Avb2F1dGgiLCJoZWFkZXJzIjpbXX0%3D)
or add `https://mcp.context7.com/mcp/oauth` under Replit Integrations.

Context7 is preferred for version-sensitive framework/library APIs. It never
overrides repository rules or locked dependencies, and agents fall back to
official vendor documentation when it is unavailable.

## Common skills

Common skills are **generated** from `AIAE-llm-aux` (pinned in `llm-aux.lock`)
into both registries. They carry provenance headers and must not be edited
here — edit the canonical source, repin, regenerate.

```bash
bash scripts/sync-llm-aux.sh --update-lock   # repin to the source's HEAD
bash scripts/sync-llm-aux.sh                 # regenerate
git add llm-aux.lock .claude/.llm-aux-manifest .agents/.llm-aux-manifest .claude/skills .agents/skills
```

Integrity is content-addressed: the lock's `revision` is the contract, not the
URL. Any source producing that commit is accepted; anything else is rejected.
Resolution order is `$LLM_AUX_SOURCE`, then a sibling `../AIAE-llm-aux`
checkout, then the lock's `repository`.

Rollback is one edit: set `revision` to the previous SHA and re-run sync.

## Handoff

Handoff strips the Replit control plane, removes MVP-only teaching/testing
features, and keeps the Claude engineering surface. It is a one-way
transformation, so it is opt-in:

```bash
bash scripts/prepare-engineering-handoff.sh            # dry run — prints, changes nothing
bash scripts/prepare-engineering-handoff.sh --apply    # requires a clean git tree
```

The command removes:

- `AGENTS.md`, `replit.md`, `.agents/`, `custom_instruction/`, and `templates/`;
- `backend/event-logging-to-db-feature`, its Liquibase change, configuration,
  safe `@LogUsage` annotations/imports, and the optional BigQuery usage sink;
- scaffold-only frontend feature folders such as
  `frontend/src/features/_template`.

Handoff blocks instead of guessing when product code still has semantic
usage-logging dependencies, downstream Liquibase references to
`usage_events`, or imports from the frontend template. It also blocks until
coverage is finalized and the strict local verification passes.

Preserved: `CLAUDE.md`, all of `.claude/`, and application source outside the
explicitly validated MVP-only cleanup above.

## Key scripts

| Script | Purpose |
|---|---|
| `scripts/new-project.sh` | Create a project locally, without Replit. |
| `scripts/sync-llm-aux.sh` | Install common skills from the pinned revision. `--check` verifies without writing. |
| `scripts/test-sync-drift.sh` | Fail if a generated skill was hand-edited. |
| `scripts/check-payload-portability.sh` | Enforce both registries + the shipped-skill contract. |
| `scripts/release-replit-template.sh` | Build the flattened Replit-importable artifact. |
| `scripts/install-claude-fixtures.sh` | Install the engineering surface into an existing project. |
| `templates/.../materialize-project.sh` | Copy the scaffold into a project. |
| `templates/.../prepare-engineering-handoff.sh` | Strip the control plane for transfer. |
| `templates/.../test-materialize-project.sh` | Materialization + handoff contract tests. |

## Documentation

- `docs/agents-lifecycle-decision.md` — why both native registries share one task store.
- `docs/claude-code-setup.md` — working with generated projects in Claude Code.
- `docs/permissions-hardening.md` — recommended `~/.claude/settings.json`.
- `docs/skill-inventory.md` — historical: the pre-split classification.
