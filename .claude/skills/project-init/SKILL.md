---
name: project-init
description: Create a new project from this template. Use when the user asks to initialize, create, set up, scaffold, or start a new project, app, or service — including phrasings like "do initialize project", "make me a new app", "start a new project", or "set this up". Runs the scaffolding for the user; they never need to type shell commands.
metadata:
  user-invocable: "true"
---

# Project Init

Create a working project from this template on the user's behalf.

Assume the user is **non-technical**. They asked for a project, not for a
command to run. Do the work, then tell them what exists and what to say next.
Never hand them a shell command as the answer.

## Before you start

Confirm you are in the template repository: `templates/generated-project/scaffold/`
and `scripts/new-project.sh` must both exist. If they do not, you are in a
generated project already — say so, and ask what they want to build instead.

## Step 1 — get two things

Ask for both in one message, with concrete examples. Do not ask anything else.

1. **What the project is called** — in plain words, e.g. "Margin Terminator".
2. **Where it should go** — offer a sensible default such as
   `~/work/<slug>` and accept it if they just say "yes" or "default".

Derive the Java package suffix yourself: lowercase the name and strip everything
that is not a letter or digit ("Margin Terminator" → `marginterminator`). Show
the derived value so they can object, but do not make them supply it.

If they will also work on Replit, keep the Replit entry points. If they say this
is local/Claude only, or they do not know what Replit is, pass `--claude-only`.
When unsure, keep them — an unused `AGENTS.md` is harmless.

## Step 2 — create it

```bash
bash scripts/new-project.sh <target-dir> <package-suffix> [--claude-only]
```

Read the output. It prints what was installed and the follow-up steps. If it
fails, translate the failure into plain language and fix the cause — do not
forward the raw error and stop.

Known failure and its meaning:

- *"target is not empty"* — the directory already has files. Ask whether they
  want a different directory, or to scaffold into the existing one anyway.
- *"template payload check failed"* — the template itself is inconsistent. Run
  `bash scripts/check-payload-portability.sh`, fix that first, and say so.

## Step 3 — make it a clean starting point

The scaffold ships sample code so the structure is demonstrable. Real work
should not start on top of it:

```bash
cd <target-dir>
bash scripts/strip-scaffold-samples.sh
```

Then verify the project is healthy:

```bash
bash scripts/local-verify.sh
```

The new project starts in the **MVP coverage phase**, so the test-coverage gate
is relaxed on purpose and will not block feature work. Do not offer to "fix"
that; it is the intended state. Mention only that coverage gets finalized later,
as a required step before handoff.

If `local-verify.sh` fails for any other reason, fix it before handing the
project over. A first run that fails teaches the user the project is broken.

## Step 4 — report

Tell them, in plain language and without shell commands:

- where the project lives;
- that the backend is Java/Spring and the frontend is React, already wired
  together;
- that the project carries its own rules and skills, so Claude Code already
  knows the conventions when they open it;
- that they can now describe the first feature in their own words.

End with the single next thing to say, for example: *"open that folder with
Claude Code and describe the first screen you want."*

## What not to do

- Do not ask for a Java package name, a git remote, or a port.
- Do not initialize git separately; `new-project.sh` initializes the repository
  but intentionally creates no commit unless `--commit` was explicitly
  requested.
- Do not create a project inside the template repository.
- Do not write application code in this step. Scaffolding and building the first
  feature are separate conversations.
