# Context path policy

Default MVP rule: **`APP_CONTEXT_PATH` is empty**. Spring serves `/api/v1/...`
directly and the frontend nginx proxy forwards `/api/*` to the backend service.

Do not add a servlet context path unless deployment infrastructure explicitly
requires one.

## When a context path is required

Set `APP_CONTEXT_PATH` consistently across:

- `application.yml` / `server.servlet.context-path`
- docker-compose backend healthcheck URL
- frontend nginx `/api/` proxy target
- Vite dev proxy (`VITE_API_CONTEXT_PATH`)

Verify manually or in CI with a non-empty path (for example `/test-app`):

- actuator health
- Prometheus metrics
- Swagger UI
- OpenAPI YAML
- frontend API proxy
- SPA deep links
- Docker backend and frontend routing

## Replit default

Replit Reserved VM deployments use an **empty** context path. Replit build/run
scripts package the SPA into the Spring Boot jar on port 5000 without a prefix.
