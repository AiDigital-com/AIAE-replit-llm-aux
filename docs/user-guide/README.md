# Building a project — step by step

For anyone who wants to build an app without writing code. You will talk to
Claude in plain language. You do not need to understand Java, React, or git, and
you will not need to type shell commands.

Each step tells you **what to do**, **what to say**, and **why it matters**.

## What this actually is

A pre-built starting point for a real, working web application: a database, a
server, a website, login, and logging — all wired together and following your
company's engineering standards.

Starting from it instead of from nothing matters because the standards are
already baked in. Claude reads them automatically, so the code it writes for you
is the kind of code your engineers would accept — not a throwaway prototype that
has to be rebuilt later.

---

## Before you start

You need **one** of these:

- **Claude desktop app** — the simplest option.
- **VS Code** with the Claude extension.

You also need the template folder on your computer. If someone sent it to you or
it is already there, you are ready. If not:

1. Open the template's page on GitHub.
2. Click the green **Code** button, then **Download ZIP**.
3. Unzip it somewhere you will find again, such as your Documents folder.

*Why:* Claude needs the folder open to see the standards and the starting point.

### Optional but recommended: current technical documentation

The template already knows how to connect Claude Code to Context7, which
supplies current documentation for React, Spring and other libraries. The first
time Claude Code needs it, approve the Context7 connection and complete the
browser login. Do not copy an API key into chat. Other Claude clients may need
their own MCP setup because `.mcp.json` is the Claude Code project format.

If you build through Replit, click
[Add Context7 to Replit](https://replit.com/integrations?mcp=eyJkaXNwbGF5TmFtZSI6IkNvbnRleHQ3IiwiYmFzZVVybCI6Imh0dHBzOi8vbWNwLmNvbnRleHQ3LmNvbS9tY3Avb2F1dGgiLCJoZWFkZXJzIjpbXX0%3D)
once and complete the login there.

---

## Step 1 — open the template with Claude

**Claude desktop app:** open it, choose to open a project or folder, and select
the `AIAE-replit-llm-aux` folder.

**VS Code:** File → Open Folder → select `AIAE-replit-llm-aux`, then open the
Claude panel.

*Why:* Claude reads instructions from the folder you open. Open the wrong folder
and it will not know the standards.

**How to tell it worked:** ask Claude *"what skills do you have here?"* It should
list things like `project-init`, `task-workflow`, and `backend-rule-review`. If
it lists nothing, you opened the wrong folder — go up or down one level and try
again.

---

## Step 2 — create your project

Say to Claude:

> **do initialize project**

Claude will ask you two things:

1. **What the project is called** — plain words are fine, e.g. *"Margin
   Terminator"*.
2. **Where to put it** — Claude suggests a folder. Say *"yes"* to accept it.

It may also ask whether you will use Replit. If you do not know what that is,
say *"no, just locally"*.

Then it does the rest and tells you where your project now lives.

*Why:* This copies the starting point, names everything consistently, and removes
the demo example code so you begin from a clean slate. Doing it by hand means a
dozen easy mistakes.

**How to tell it worked:** Claude reports the folder location and confirms the
project passed its own health check.

---

## Step 3 — open your new project

Open the **new** folder in Claude — the one it just told you about, not the
template.

Open the folder that directly contains `backend`, `frontend`, and `CLAUDE.md`.
Do not open a folder inside it.

*Why:* Your project carries its own copy of the standards. From here on you work
in your project, and the template is no longer involved.

---

## Step 4 — describe what you want

Talk in terms of what the user of your app should be able to do, not in terms of
code.

Good:

> I need a page where a manager uploads a spreadsheet of deals, sees which ones
> are below 15% margin, and can leave a comment on each one.

Not useful:

> Create a REST controller with a POST endpoint.

Claude will plan the work, write it, review its own work, and verify it. It may
ask questions — answer in plain language.

*Why:* You know the business problem; Claude knows how to build it to standard.
Describing outcomes lets each side do the part it is good at.

---

## Step 5 — check it actually works

Ask Claude:

> **run the app and show me it working**

It will start the app and tell you what to open in your browser.

If something is broken, say what you see:

> the upload button does nothing when I click it

*Why:* Working software is the only real progress. A feature nobody has opened in
a browser is not finished.

---

## Step 6 — when the project is finished

This step is **required** and cannot be skipped. Say:

> **finalize coverage**

Claude will write the automated tests that prove the app behaves correctly, then
switch the project into its final, strict mode.

*Why:* While you are still figuring out what to build, demanding full tests would
slow you down for no benefit — so the requirement is deliberately relaxed. Once
the product is settled, those tests are what let another team change the code
later without breaking what you built. This is the moment that debt gets paid,
and the tooling will not let the project move on until it is.

Expect this to take real time. It is finishing work, not a formality.

---

## Step 7 — hand it to engineering

Say:

> **prepare this project for engineering handoff**

Claude runs the safety review, removes the template's internal scaffolding, and
produces a summary of what needs replacing before production.

*Why:* Engineering receives a clean repository with the rules it was built under,
and a written list of what was mocked or simplified — instead of having to guess.

---

## Things worth knowing

**You cannot break it by asking.** Claude explains before doing anything
destructive, and everything is tracked in git, so changes can be undone.

**Say when something looks wrong.** "That is not what I meant" is useful
information. So is "why did you do it that way?"

**Coverage will feel like an obstacle at the end.** It is the intended design.
The relaxed early gate exists so you can move fast; the strict final gate exists
so what you built survives.

**Ask for a status any time:**

> what is left to do before this project can be handed over?

---

## If you get stuck

| What you see | What to say to Claude |
|---|---|
| Claude does not know the standards | *"what skills do you have here?"* — if empty, you opened the wrong folder |
| "target is not empty" | *"use a different folder"* |
| The app will not start | *"the app will not start, here is what I see: ..."* |
| Handoff is blocked | *"finalize coverage"* — the required step is not done |
| You do not know what stage you are at | *"what stage is this project at?"* |

---

## I downloaded my project from Replit — does it still work?

Yes. Open the downloaded folder in Claude and the repository rules and skills
work immediately. Context7 is optional and may ask each developer for a one-time
OAuth approval because authentication is intentionally not stored in the
project.

Your project carries its own copy of the standards inside a `.claude` folder,
which travels with the download. There is nothing to install and nothing to
connect.

Two things to get right:

1. **Open the folder that contains `backend`, `frontend`, and `CLAUDE.md`.** If
   you open a folder inside it, Claude will not find the standards.
2. **Do not delete the `.claude` folder.** It looks like clutter — it is the part
   that tells Claude how your project works.

To confirm, ask Claude *"what skills do you have here?"* and check it lists
`task-workflow` and `backend-rule-review`.

You will notice the template's own internal folders (`templates`,
`custom_instruction`) are absent from the download. That is deliberate; nothing
your project needs refers to them.
