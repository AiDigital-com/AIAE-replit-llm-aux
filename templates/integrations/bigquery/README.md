# BigQuery adapter (opt-in)

Integrates Google BigQuery as an optional analytics export sink. The default baseline
usage-logging target is the PostgreSQL `usage_events` table — install this pack
only when an additional BigQuery export is needed.

This pack installs the HTTP client foundation automatically and depends on the
MVP `event-logging-to-db-feature`. Install it before engineering handoff. The
handoff command removes the usage-event sink and its dependency together with
the rest of MVP usage logging.

## Install

```bash
PROJECT_ROOT=/path/to/project bash templates/integrations/bigquery/install.sh
```

## Configuration

Set the required variables. The service-account JSON is read from an environment
variable as a string; do not mount a file.

```env
# Local development without Google credentials:
BIGQUERY_ENABLED=true
BIGQUERY_STUB_ENABLED=true
BIGQUERY_PROJECT_ID=demo-project
BIGQUERY_DATASET=analytics

# Production export (requires service-account JSON string):
BIGQUERY_ENABLED=true
BIGQUERY_STUB_ENABLED=false
BIGQUERY_CREDENTIALS_JSON={"type":"service_account","project_id":"..."}
BIGQUERY_PROJECT_ID=my-gcp-project
BIGQUERY_DATASET=analytics
BIGQUERY_LOCATION=US
```

When BigQuery is active, `BigQueryUsageEventSink` becomes the primary usage
analytics route; failures fall back to PostgreSQL automatically.

Leave `BIGQUERY_ENABLED=false` (default) to keep usage analytics on PostgreSQL only.

## Security

- Never commit service-account JSON.
- Store `BIGQUERY_CREDENTIALS_JSON` in a secret manager / environment variable.
- Credential JSON is never logged.
- The default sink is PostgreSQL — BigQuery is additive only.

## What is installed

| File | Description |
|------|-------------|
| `BigQueryClient` | Application-facing interface (`insertRow`) |
| `BigQueryClientImpl` | Google Cloud BigQuery SDK integration |
| `BigQueryProperties` | Typed `@ConfigurationProperties` |
| `BigQueryStubClient` | In-memory client when `stub-enabled=true` |
| `BigQueryConfig` | `@ConditionalOnProperty` beans (stub or production) |
| `BigQueryUsageEventSink` | Optional primary usage analytics export |
| `BigQueryExternalException` | Runtime exception for SDK failures |

The generic `BigQueryClient` remains usable for deliberate product
integrations. Only the usage-logging sink is coupled to the MVP telemetry
feature and removed during handoff.
