# Permissions Hardening

This document describes the recommended Claude Code permissions configuration
for working with AIAE projects. These are **machine-global** settings in
`~/.claude/settings.json` — they are NOT embedded in generated projects, because
a project must not impose write permissions on every developer who clones it.

The shared AIAE repositories are hosted by the
[`AiDigital-com`](https://github.com/AiDigital-com) GitHub organization.
Repository hosting does not grant an agent permission to publish changes.

## Principle

Read-only operations and safe build/test commands are allowed automatically.
Operations that modify Git state, generated registries, or GitHub require
confirmation.

## Recommended `~/.claude/settings.json`

```json
{
  "permissions": {
    "allow": [
      "Bash(git status *)",
      "Bash(git diff *)",
      "Bash(git show *)",
      "Bash(git log *)",
      "Bash(mvn test *)",
      "Bash(mvn verify *)",
      "Bash(mvn compile *)",
      "Bash(npm test *)",
      "Bash(npm run lint *)",
      "Bash(npm run typecheck *)",
      "Bash(npm run build *)",
      "Bash(npm run check:api *)",
      "Bash(bash scripts/local-verify.sh)",
      "Bash(bash scripts/structure-lint.sh)",
      "Bash(bash scripts/verify-gates.sh)",
      "Bash(bash scripts/sync-llm-aux.sh --check)",
      "Bash(gh repo view *)",
      "Bash(gh pr list *)",
      "Bash(gh pr view *)",
      "Bash(gh issue list *)",
      "Bash(gh issue view *)",
      "Bash(gh run list *)",
      "Bash(gh run view *)"
    ],
    "ask": [
      "Bash(git fetch *)",
      "Bash(git pull *)",
      "Bash(git checkout *)",
      "Bash(git switch *)",
      "Bash(git restore *)",
      "Bash(git clean *)",
      "Bash(git stash *)",
      "Bash(git add *)",
      "Bash(git commit *)",
      "Bash(git push *)",
      "Bash(git rebase *)",
      "Bash(git reset *)",
      "Bash(bash scripts/sync-llm-aux.sh)",
      "Bash(bash scripts/sync-llm-aux.sh --update-lock *)",
      "Bash(gh pr create *)",
      "Bash(gh pr merge *)",
      "Bash(gh pr close *)",
      "Bash(gh issue create *)",
      "Bash(gh issue close *)",
      "Bash(gh issue comment *)",
      "Bash(gh release create *)",
      "Bash(gh api *)"
    ],
    "deny": [
      "Read(./.env)",
      "Read(./.env.local)",
      "Read(./.env.*.local)",
      "Read(./secrets/**)",
      "Read(./**/*credentials*.json)",
      "Read(./**/*service-account*.json)"
    ]
  }
}
```

## Why these choices

### `allow` — read-only or local verification

- `git status/diff/show/log` — read local Git state without changing it.
- `mvn test/verify/compile`, `npm test/build/typecheck` — local build commands.
- scaffold verification scripts — read-only gates.
- `sync-llm-aux.sh --check` — verifies generated skills without rewriting them.
- GitHub CLI `view` and `list` commands — read repository, PR, issue, workflow,
  and run state.

### `ask` — confirmation required

- `git fetch/pull` — update local references or the working tree from GitHub.
- `git checkout/switch/restore/clean/stash` — change the working tree or hide
  uncommitted work.
- `git add` — changes the staged scope that a later commit will publish.
- `git commit` — creates history; the user should control the message and scope.
- `git push` — publishes to a remote; irreversible.
- `git rebase/reset` — rewrite history.
- `sync-llm-aux.sh` without `--check` — rewrites generated registries and
  manifests; `--update-lock` additionally changes the pinned common revision.
- GitHub create, merge, close, comment, release, and generic `gh api` commands —
  modify remote state or are too broad to auto-approve safely.

### `deny` — never without explicit override

- local `.env` and credential files — deny rules reduce accidental reads, but
  do not constrain shell commands such as `cat`. `.env.example` intentionally
  remains readable because it is the committed configuration contract. Use
  Claude sandbox filesystem policy, OS permissions, and secret managers when
  secrets require enforcement.

Commands not listed under `allow` should retain Claude Code's confirmation
behavior. The `ask` list highlights common risky actions; it is not an
exhaustive inventory of every possible Git or GitHub write command.

## Skill-specific tool restrictions

Review and audit skills should not have remote write capabilities. When a
skill is invoked with `allowed-tools` frontmatter (target-specific, added by
the consuming project), restrict it to read-only tools:

```yaml
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(git status *)
  - Bash(git diff *)
  - Bash(git show *)
  - Bash(git log *)
```

No `git add`, `git checkout`, `git commit`, `git push`, or MCP write tools in
review/audit skills. Avoid broad `comments` MCP allow rules because they may
write; allow only verified read-only connector operations.

## GitHub connectors and MCP tools

GitHub connector and MCP tool names vary by client and installed integration,
so this repository does not guess wildcard names for them. Apply the same
capability policy when configuring one:

- list, get, search, and view operations may be allowed;
- create, update, delete, merge, close, comment, dispatch, upload, and other
  remote writes require confirmation;
- unknown or overly broad operations require confirmation.

Authenticate GitHub through the developer's local `gh`/connector session.
Never commit a GitHub token or ask a user to paste one into agent chat.
