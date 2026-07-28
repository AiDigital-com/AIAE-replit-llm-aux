# Logbook HTTP Logging Rules

Backend logs inbound + outbound HTTP metadata via Zalando Logbook. Logbook and
inbound application observability remain application-owned. Reusable outbound
timing is separate and attachable, and product usage analytics remains a third,
independent concern.

## Module Boundary

- `application` owns `LogbookConfig`, `CorrelationIdFilter`,
  `src/main/resources/logback-spring.xml`, the Logbook/structured-log/Actuator/
  Prometheus dependencies, and endpoint exposure/security configuration.
- `backend/observability` owns only reusable outbound metric helpers:
  `ExternalClientMetricsInterceptor` and `ExternalCallTimer`.
- `external-services` consumes the application-composed `Logbook` bean and the
  reusable metrics module. It must not define a second Logbook configuration or
  a second external-call timer schema.
- Product usage analytics remains separately attachable in
  `event-logging-to-db-feature`; do not mix business-event persistence into
  operational request logging.

## Required Dependency

- `backend/application` declares
  `org.zalando:logbook-spring-boot-starter` (version managed in parent POM).

## Required Configuration

`LogbookConfig` in `backend/application`:

- register `Logbook` bean
- `JsonHttpLogFormatter` (JSON request/response logs)
- `DefaultHttpLogWriter`
- use `WithoutBodyStrategy` so production/Replit output is metadata-only
- exclude noisy infrastructure
- mask sensitive headers + JSON body fields

## Body Logging Policy

- Production/Replit logging is body-free by default. Metadata includes the
  correlation id, method, URI/route, status, and supported timing/size fields.
- Never log raw documents, credentials, JWTs, service-account JSON, API keys,
  PII, uploads, or arbitrary/generated user content.
- Temporary local body logging requires an explicit debugging need, strict
  redaction, small truncation bounds, and removal before completion. It must not
  be enabled through a production/Replit profile.

## Outbound Third-Party HTTP

- Every Spring `RestClient`/`RestTemplate` used for third-party communication
  MUST register
  `org.zalando.logbook.spring.LogbookClientHttpRequestInterceptor`.
- Generated integrations MUST obtain clients from `PooledRestClientFactory`;
  direct uninstrumented client builders are forbidden.
- The factory injects the single application-composed `Logbook` bean
  and registers `new LogbookClientHttpRequestInterceptor(logbook)` on every
  client.
- The same factory registers the reusable
  `new ExternalClientMetricsInterceptor(name, meterRegistry)`. SDK-managed
  transports are wrapped with `ExternalCallTimer` using fixed client/operation
  names.
- SDK-managed transports are not an observability bypass: document and test
  their equivalent redacted request/error/latency telemetry before acceptance.

## Exclusions

Do not log:

- `/health`
- `/actuator/**`
- `/swagger-ui/**`
- `/api/v1/specs/**`
- static assets
- OPTIONS requests
- readiness/liveness probes

## Required Header Masking

Mask at least:

- `Authorization`
- `Cookie`
- `Set-Cookie`
- `X-API-Key`
- `AccessKey`
- `Proxy-Authorization`
- `X-Goog-*`

## Required JSON Field Masking

Mask fields matching:

- `.*password.*`
- `.*token.*`
- `.*secret.*`
- `.*key.*`
- `.*credential.*`
- `.*authorization.*`
- `privateKey`
- `clientSecret`
- `serviceAccount`

Replacement value:

- `XXX`

## Application YAML Baseline

```yaml
logging:
  level:
    org.zalando.logbook: TRACE

app:
  logbook:
    censored-replacement: XXX
    headers-to-censor:
      - Authorization
      - Cookie
      - Set-Cookie
      - X-API-Key
      - AccessKey
      - Proxy-Authorization
    json-fields-to-censor:
      - .*password.*
      - .*token.*
      - .*secret.*
      - .*key.*
      - .*credential.*
      - .*authorization.*
      - privateKey
      - clientSecret
      - serviceAccount
    excluded:
      "/**/actuator/**":
        - GET
      "/**/swagger-ui/**":
        - GET
      "/**/specs/**":
        - GET
      "/health":
        - GET
      "/**":
        - OPTIONS
```

## Acceptance Checks

- normal inbound and outbound requests log bounded metadata without bodies
- `Authorization` is masked
- JSON token/password/secret fields are masked
- `/actuator/health` is not logged
- OPTIONS request is not logged
- every generated third-party Spring HTTP client contains
  both `ExternalClientMetricsInterceptor` and
  `LogbookClientHttpRequestInterceptor`
- SDK-managed external calls use `ExternalCallTimer` with fixed
  low-cardinality client/operation tags
- `LogbookConfig`, `CorrelationIdFilter`, and `logback-spring.xml` remain in
  `backend/application`
- `ExternalClientMetricsInterceptor` and `ExternalCallTimer` remain in
  `backend/observability`
