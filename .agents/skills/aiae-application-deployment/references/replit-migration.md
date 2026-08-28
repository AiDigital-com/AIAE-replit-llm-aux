# Replit to AIAE AWS Migration

Read this reference only when the source repository contains Replit artifacts
or the live application is hosted on Replit.

The goal is not merely to delete `.replit`. The goal is to preserve required
behavior on AWS, remove Replit-only assumptions, and leave no secret material in
source or chat.

## 1. Inventory before deletion

Inspect and record:

- `.replit`, `replit.nix`, deployment sections, run commands, build commands,
  ports, health checks, and workflow tasks;
- Replit-specific shell scripts, package scripts, Procfiles, Dockerfiles, and
  generated deployment files;
- application profiles named `replit` and conditional code that checks the
  Replit environment;
- Replit domains in authorized parties, CORS, CSP, Clerk configuration, OAuth
  redirects, iframe allowlists, API base URLs, and frontend environment files;
- filesystem assumptions such as persistent local disk or writable source tree;
- Replit database, object storage, scheduled jobs, or secret access;
- README instructions and CI workflows that still describe Replit deployment.

Also search source and configuration for every environment key the application
reads. The absence of a key from `.replit` does not mean the key is unused;
Replit Secrets are not normally stored in the repository.

## 2. Build a migration matrix

For every artifact or setting, record:

| Replit source | Behavior | AWS replacement | Destination owner | Remove after verification? |
|---|---|---|---|---|
| `.replit` run command | Starts backend | Container command/Dockerfile | Application repository | yes |
| Replit deployment build | Builds frontend | GitHub Actions build | Application repository | yes |
| Replit secret key name | Runtime credential | AWS Secrets Manager JSON key | User/platform | key reference remains; value never copied by agent |
| Replit domain | Browser origin | DEV CloudFront or PROD custom domain | Helm/app auth config | yes after cutover |

Do not remove an item whose replacement is unknown or unverified.

## 3. Classify configuration

### Application runtime secrets

Place in the environment's AWS Secrets Manager application secret:

- DEV: `AIAE-DEV/<application-slug>`
- PROD: `AIAE-PRD/<application-slug>`

Derive the exact JSON keys from source. Common categories include database
credentials, OAuth/Clerk secret keys, external API tokens, signing keys, and
service-account JSON.

Tell the user:

1. exact secret name;
2. exact required JSON keys;
3. whether a value is plain text, JSON, or multiline;
4. which environment needs it;
5. how the skill will verify key presence without reading values.

Never ask the user to paste the values into chat. Do not copy values from local
`.env` files, password managers, screenshots, or Replit into command history.

### Non-sensitive runtime configuration

Place environment-specific settings in the `AIAE-helm` DEV/PROD values and
render them through a ConfigMap. Examples include ports, dataset names,
locations, feature flags, allowed origins, and log environment labels.

Do not preserve `PRD_` key duplication when DEV and PROD already have separate
configuration sources. Use one application property name and provide different
environment values.

### Frontend build configuration

Anything compiled into browser JavaScript is public. It may still be sourced
centrally from Secrets Manager for environment consistency, but it is not made
secret by doing so. Keep true server secrets out of frontend variables.

### Deployment credentials

Keep AWS role ARNs and resource IDs in GitHub environment variables. Keep the
GitOps repository credential in a GitHub environment secret. They do not belong
in the application Secrets Manager JSON.

## 4. Replace Replit runtime behavior

Verify the AWS implementation covers:

- container starts with the real production command;
- application listens on the configured container port and `0.0.0.0`;
- health probes do not require authentication;
- runtime is stateless or persistent data uses an approved AWS service;
- database migrations run before rollout, not automatically in every app pod;
- environment-specific authorized parties, CORS, CSP, OAuth redirects, and
  Clerk settings use the new URLs;
- logs go to stdout in the expected structured format;
- health probes are filtered from verbose request logs when required;
- production metrics endpoint is exposed to the approved collector only;
- frontend API requests use CloudFront/ALB routes instead of a Replit hostname.

Do not keep `SPRING_PROFILES_ACTIVE=replit` merely to obtain logging or tuning.
Move generally valid settings to the base configuration and AWS-specific
settings to an `eks` profile when the application uses Spring. Apply the same
principle to other frameworks.

## 5. Safe cleanup order

1. Complete the inventory and migration matrix.
2. Create AWS/GitHub/Helm replacements.
3. Ask the user to populate required secret keys through the approved UI or
   secret-entry mechanism.
4. Have the user run the no-value key checker locally and report only `PASS` or
   missing key names.
5. Deploy and verify DEV on AWS.
6. Determine whether Replit auto-deploys from the branch that will receive the
   cleanup. Preserve the current Replit revision as a rollback target.
7. If Replit still serves production traffic, freeze/detach its deployment from
   future source changes or defer cleanup until AWS PROD cutover and the agreed
   stabilization window are complete.
8. Remove Replit-only files, profiles, scripts, dependencies, and documentation
   only when cleanup commits cannot replace the known-good Replit fallback.
9. Remove Replit domains from application configuration after replacement URLs
   work.
10. Search the full repository case-insensitively for remaining `replit`, old
   hostnames, old profiles, and removed script names.
11. Re-run backend tests, frontend tests/build, container builds, and DEV smoke
   tests.
12. Prepare and verify PROD.
13. Cut DNS over only after the AWS PROD endpoint and certificate are ready.
14. Retire the Replit deployment only after DNS resolution, TLS, login, API,
   database, logs, and rollback are verified from an external client.

Deleting the Replit application is an external destructive action and requires
explicit user confirmation.

## 6. Cleanup acceptance criteria

Replit removal is complete only when:

- AWS DEV and requested PROD flows work without Replit;
- no runtime command depends on Replit metadata or environment variables;
- no production auth/CORS/CSP/API URL points to Replit;
- all required configuration keys have documented destinations;
- no secret value entered source history or logs;
- repository search finds no unexplained Replit references;
- local-development scripts still work or have documented replacements;
- the old Replit deployment can be stopped without affecting AWS traffic.
