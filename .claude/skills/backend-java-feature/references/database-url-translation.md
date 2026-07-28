# Replit Datasource Env Wiring

Replit's `postgresql-16` module exposes Postgres connection details to the
process environment. Generated Spring apps configure the Replit profile
directly from the individual variables:

```text
PGHOST
PGPORT
PGDATABASE
PGUSER
PGPASSWORD
```

`DATABASE_URL` may also exist, but the canonical Spring configuration does not
parse it and does not require a custom `EnvironmentPostProcessor`.

## Canonical `application-replit.yml`

Use this shape in `backend/application/src/main/resources/application-replit.yml`:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://${PGHOST:${POSTGRES_HOST:localhost}}:${PGPORT:${POSTGRES_PORT:5432}}/${PGDATABASE:${POSTGRES_DB:app}}
    username: ${PGUSER:${POSTGRES_USER:app}}
    password: ${PGPASSWORD:${POSTGRES_PASSWORD:app}}
    hikari:
      maximum-pool-size: 3
      minimum-idle: 0
      idle-timeout: 30000
      connection-timeout: 5000
      auto-commit: false
```

Rules:
- Keep `maximum-pool-size` at `2-3` on Replit. Do not copy the local-dev `50`.
- Do not append `?sslmode=require` by default. Current Replit Postgres works
  without SSL; forcing SSL broke real generated apps.
- Do not add `ReplitDatabaseUrlPostProcessor`, `spring.factories`,
  `EnvironmentPostProcessor.imports`, or a custom `DataSource` bean for the
  Replit profile.
- If a future Replit tier explicitly requires SSL, add it only after verifying
  the actual env values and document the reason in README.

## Why not `EnvironmentPostProcessor`

Spring Boot 3.x still loads `EnvironmentPostProcessor` implementations from
`META-INF/spring.factories`. The `META-INF/spring/...imports` pattern is for
auto-configuration imports, not this hook. Past generated apps registered the
post-processor in the wrong place, so the class was correct but never ran.

The direct YAML approach is simpler and observable: `env | grep '^PG'` shows the
same values Spring consumes.

## Local-dev profile

`application-local.yml` uses the same property names via `.env` /
docker-compose values:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://${POSTGRES_HOST:localhost}:${POSTGRES_PORT:5432}/${POSTGRES_DB:app}
    username: ${POSTGRES_USER:app}
    password: ${POSTGRES_PASSWORD:app}
```

Local-dev may use Hikari `maximum-pool-size: 50`.
