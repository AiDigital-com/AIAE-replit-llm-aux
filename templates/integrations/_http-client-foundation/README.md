# HTTP client foundation (opt-in)

Install with the **first** outbound HTTP integration pack only. Do not add this
module to projects without real external API calls.

## Contains

- `PooledHttpClientProperties`
- `PooledRestClientFactory`
- `ManagedPooledRestClient` lifecycle management and shutdown cleanup
- `ExternalHttpException` base exception for adapters
- Apache HttpClient 5 wiring for Spring `RestClient`
- mandatory `LogbookClientHttpRequestInterceptor` registration using the
  application-owned `Logbook` bean
- reusable `ExternalClientMetricsInterceptor` from `backend/observability` for
  the shared `external.client.requests` timer schema
- connection pool, connect, response, and pool-acquisition timeout settings
- focused configuration tests

## Install

```bash
PROJECT_ROOT=/path/to/project \
  bash templates/integrations/_http-client-foundation/install.sh
```

The installer creates `backend/external-services`, adds it to the application
runtime assembly, and is idempotent. Claude and OpenAI packs install this
foundation automatically; later HTTP integration packs reuse it instead of
copying transport code.
