# Google Workspace adapter (opt-in)

Integrates Google Docs, Drive, Sheets, and Slides as individually selectable
external services. Enable only the APIs your project needs.

## Install

```bash
PROJECT_ROOT=/path/to/project bash templates/integrations/google-workspace/install.sh
```

## Configuration

Set the service-account JSON as an environment variable string:

```env
GOOGLE_WORKSPACE_CREDENTIALS_JSON={"type":"service_account","project_id":"..."}
GOOGLE_WORKSPACE_DOCS_ENABLED=true
GOOGLE_WORKSPACE_DRIVE_ENABLED=false
GOOGLE_WORKSPACE_SHEETS_ENABLED=false
GOOGLE_WORKSPACE_SLIDES_ENABLED=false
```

For local development without real credentials:

```env
GOOGLE_WORKSPACE_STUB_ENABLED=true
```

Stub mode registers deterministic clients for all four services. In production,
enable only the required service flags and share the corresponding Docs, Drive,
Sheets, or Slides resources with the configured service account.

## Security

- Never commit service-account JSON.
- Store `GOOGLE_WORKSPACE_CREDENTIALS_JSON` in a secret manager / environment variable; do not mount a file.
- Credentials are never logged.
- Add `gsa.json` and similar patterns to `.gitignore` and secret scanning rules.

## What is installed

| Interface | Description |
|-----------|-------------|
| `GoogleDocsClient` | Read document content |
| `GoogleDriveClient` | List files in a folder |
| `GoogleSheetsClient` | Read a spreadsheet range |
| `GoogleSlidesClient` | Get a presentation title |

Each interface has:

- a Google API Client Library production implementation;
- a deterministic stub implementation for local development and tests;
- conditional Spring configuration controlled by its `*_ENABLED` flag.

The installer pins and adds the required Google API, auth, HTTP, and Gson
dependencies to the generated backend. No manual POM editing is required.
