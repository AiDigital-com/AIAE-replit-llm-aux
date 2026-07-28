# Context7 Documentation Lookup

Context7 is the preferred MCP source for current, version-specific library and
framework documentation. The repository commits only the public MCP endpoint;
authentication remains local to each developer or Replit account.

## Claude Code

The generated project contains a project-level `.mcp.json` pointing to:

```text
https://mcp.context7.com/mcp/oauth
```

Claude Code asks the user to approve the project MCP server and complete OAuth
when it is first used. Do not add an API key to `.mcp.json`.

If a client cannot use the committed project MCP entry, run Context7's device
flow instead:

```bash
npx ctx7 setup --claude
```

It prints a verification URL and short code, so it also works from headless and
SSH environments. Without `--project`, setup writes to the user's Claude
configuration rather than the repository.

For fully non-interactive automation only, an existing dashboard key may be
supplied with `--api-key "$CONTEXT7_API_KEY"`. Keep it in the local shell or
secret manager. Never paste it into agent chat, commit it, put it in
`.env.example`, or expose it through a frontend environment variable.

## Replit Agent

Replit MCP connections are account-level integrations, not project files.
Connect Context7 once using the project README link or add a custom MCP server
in Replit Integrations with:

```text
Display name: Context7
URL: https://mcp.context7.com/mcp/oauth
```

Complete OAuth in the Replit UI. Do not put a Context7 key in application
Secrets expecting Replit Agent to discover it; application runtime secrets and
Agent MCP integration credentials are separate surfaces.

## Agent usage contract

- Use Context7 for library/framework API questions, dependency upgrades, setup,
  configuration, and code generation whose correctness depends on a particular
  version.
- Query with the library, version, and focused technical question. Do not send
  credentials, customer data, proprietary source, or an entire user prompt.
- Prefer a known exact Context7 library ID when available.
- Treat retrieved documentation as evidence, not permission to replace
  repository-local architecture or locked dependency versions.
- If Context7 is unavailable or unauthenticated, say so briefly and use the
  library's official documentation. Do not guess an API and do not block
  unrelated implementation work.
