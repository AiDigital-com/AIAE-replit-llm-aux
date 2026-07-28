# Feature module template

Copy this folder to `features/<your-feature>/` when adding product UI.

```
features/<feature-name>/
  index.ts              # public exports
  ui/<FeaturePage>.tsx  # presentational components
  api/                  # TanStack Query hooks (optional subfolder)
  <feature>.test.tsx    # behavior test
```

**Working example in this folder:** `TemplateProfilePanel` + `useAuthMeQuery` +
`template.test.tsx` — copy and rename it for the first real feature. The
engineering-handoff command removes `_template` and blocks while application
code still imports it.

Rules:
- Pages in `src/pages/` compose features; they stay thin.
- Keep application routing in `app/AppRoot.tsx` under `BrowserRouter`; features
  and pages must not create competing routers.
- All API calls go through `shared/api/client.ts`.
- Use `LoadingBlock`, `ErrorAlert`, `EmptyState` for async states.
- BEM class names — see `.claude/agent_docs/frontend/bem-naming-rules.md`.
- CSS uses semantic tokens and `rem`, not raw `px`; flexbox for rows/stacks,
  grid for table-like/multi-column layouts.
- Forms must validate required OpenAPI fields and expose accessible errors
  before submit.
- Long user/API strings and wrapped button labels must not overflow mobile or
  desktop layouts.
