# AIAE AWS Deployment Context

Read this reference before planning AIAE deployment work. It records the known
platform model verified against the Operational Hub deployment on 28 August
2026. Re-check repositories and live state because revisions and resource names
can change.

## Non-negotiable architecture

The platform separates build, desired state, and runtime:

```text
Application repository
  -> GitHub Actions
  -> ECR application + migration images
  -> S3/CloudFront frontend
  -> AIAE-helm-versions exact image tags
  -> AIAE-helm environment branch pins versions commit
  -> AWS-managed Argo CD reconciles EKS
  -> PreSync migration Job
  -> Kubernetes Deployment/Service/Ingress
```

GitHub Actions does not apply workload manifests directly to Kubernetes. It
builds artifacts and updates GitOps repositories. Argo CD owns Kubernetes
reconciliation.

## Accounts and shared environments

| Environment | AWS account | Region | Namespace | Root Application |
|---|---:|---|---|---|
| DEV | `496336474487` | `us-east-1` | `aiae-dev` | `aiae-dev-root` |
| PROD | `125093118532` | `us-east-1` | `aiae-prod` | `aiae-prod-root` |

Known cluster names currently retain the first implementation's resource prefix:

- DEV: `aiae-operational-hub-dev`
- PROD: `aiae-operational-hub-prod`

They are shared AIAE clusters despite those names. A new application in these
environments normally does not create another EKS cluster or Argo CD instance.

Each environment has its own AWS-managed Argo CD capability and root
Application. Each deployable backend is represented by a child Application.

## Repository ownership

| Repository | Branches | Responsibility |
|---|---|---|
| `AiDigital-com/<application-repository>` | product and `X.Y.Z` release branches | Product code, tests, Dockerfiles, DEV/PROD/rollback workflows. |
| [`AiDigital-com/AIAE-helm`](https://github.com/AiDigital-com/AIAE-helm) | `main` | Deployable Helm charts: Deployment, Service, Ingress, probes, autoscaling, secret projection, and optional migration Job. |
| [`AiDigital-com/AIAE-helm`](https://github.com/AiDigital-com/AIAE-helm) | `dev`, `prod` | Environment root chart, one child Application template and environment values per service, plus pinned chart and versions revisions. |
| [`AiDigital-com/AIAE-helm-versions`](https://github.com/AiDigital-com/AIAE-helm-versions) | `main` | Small values file per deployable service containing exact application and migration image tags. |
| [`AiDigital-com/AIAE-aws-infra`](https://github.com/AiDigital-com/AIAE-aws-infra) | `main` | Terraform for shared AWS platform plus application-scoped AWS resources. |

Directory names are not authoritative. Identify repositories from `origin`
remote URLs.

## Existing GitOps pattern

The current chart is named `operational-hub-api`; it is an implementation
reference, not a mandatory name or universal application contract.

Its child Application uses two Argo sources:

1. chart structure from a pinned `AIAE-helm/main` commit;
2. image values from a pinned `AIAE-helm-versions/main` commit.

The environment root branch pins both commits. Automated sync uses prune and
self-heal. A change is complete only after the child Application is Healthy and
Synced to the intended revisions.

The current migration pattern is an Argo CD `PreSync` Job. The migration image
contains the Maven project and Liquibase changelogs. The Job invokes the Maven
Liquibase goal with PostgreSQL host, port, database, username, and password read
from the Secrets Store CSI mount. The backend runtime has automatic Liquibase
execution disabled in application configuration.

Do not require this pattern for an application without Liquibase. Determine the
real migration tool and provide an equivalent pre-deployment gate when database
schema changes must precede rollout.

## Current release behavior

The Operational Hub workflows demonstrate the expected lifecycle:

- DEV is triggered by a push to a branch matching `X.Y.Z`, but the job runs only
  when that branch equals the GitHub `DEV_DEPLOY_BRANCH` variable.
- DEV application tag: `X.Y.Z-snapshot-<12-character-commit>`.
- DEV migration tag: `liquibase-X.Y.Z-snapshot-<12-character-commit>`.
- PROD release is manual and must be started from the branch matching the
  requested `X.Y.Z` release version.
- PROD application tag: `X.Y.Z-<12-character-commit>`.
- PROD migration tag: `liquibase-X.Y.Z-<12-character-commit>`.
- ECR tags are immutable. A rerun for an existing commit reuses existing images.
- PROD saves versioned frontend assets and release metadata so a rollback can
  restore a complete backend, migration, and frontend release.
- PROD release and rollback share one concurrency group. New applications must
  use an application-specific concurrency group while updates to shared GitOps
  repositories remain serialized and rebased safely.

Do not copy workflow constants blindly. Parameterize application name, ECR
repository, Dockerfiles, frontend path, chart values path, and concurrency group.

## Current GitHub environment contract

Each application repository normally has GitHub environments `dev` and `prod`.

Environment variables used by the current workflow:

| Variable | Purpose |
|---|---|
| `AWS_ROLE_TO_ASSUME` | Environment-specific GitHub OIDC role from Terraform. |
| `AWS_REGION` | `us-east-1`. |
| `FRONTEND_BUCKET` | S3 bucket output when the app has a frontend. |
| `FRONTEND_DISTRIBUTION_ID` | CloudFront output when the app has a frontend. |
| `APP_CONFIG_SECRET_NAME` | Environment-specific Secrets Manager name. |
| `GITOPS_HELM_REPOSITORY` | `AiDigital-com/AIAE-helm`. |
| `GITOPS_VERSIONS_REPOSITORY` | `AiDigital-com/AIAE-helm-versions`. |
| `DEV_DEPLOY_BRANCH` | Single numbered branch allowed to auto-deploy to DEV; DEV only. |

The current workflows use environment secret `GITOPS_TOKEN` for write access to
the two GitOps repositories. Prefer a narrowly scoped organization-approved
credential. Never store it in source, Terraform variables, Helm values, or
Secrets Manager application configuration.

Not every application needs frontend variables. Validate required variables
conditionally according to the application contract.

## Configuration placement

| Kind | Correct location | Notes |
|---|---|---|
| Non-sensitive runtime setting | `AIAE-helm` environment values -> ConfigMap | Examples: port, feature flag, allowed origin, dataset name. |
| Backend secret | AWS Secrets Manager -> Secrets Store CSI -> Kubernetes Secret -> Pod env | Never commit values. |
| Frontend build-time public setting | Workflow obtains environment-specific value, then passes it to the build | Values embedded in browser JavaScript are public even if sourced from Secrets Manager. |
| GitHub deployment setting | GitHub environment variable | Usually populated from Terraform outputs. |
| GitOps write credential | GitHub environment secret | Repository-scoped, never printed. |
| Database master password | RDS-managed Secrets Manager secret | Map required connection keys into the application secret without exposing values. |

Recommended application secret names:

- DEV: `AIAE-DEV/<application-slug>`
- PROD: `AIAE-PRD/<application-slug>`

The exact JSON keys come from application repository analysis. Do not assume
Operational Hub keys apply to another application.

## Shared versus application-scoped resources

Reuse these environment resources:

- VPC, public/private/database subnets, NAT, route tables, and security baseline;
- EKS cluster, node capacity, cluster OIDC provider, and namespace;
- AWS-managed Argo CD capability and environment root Application;
- GitHub OIDC provider and GitHub CodeConnections connection;
- Secrets Store CSI driver and common cluster add-ons;
- PROD monitoring/log-delivery platform unless the application has a justified
  separate compliance boundary.

Create or configure these per application as required:

- ECR repository and lifecycle policy;
- GitHub Actions OIDC role with access only to that application's artifacts;
- Kubernetes ServiceAccount IAM role and least-privilege policies;
- Secrets Manager application secret;
- child Argo Application, chart, and versions values;
- optional RDS database/instance, S3 buckets, CloudFront distribution, ACM
  certificate, queues, schedules, or application-specific object storage;
- application dashboards, scrape target, and CloudWatch log routing labels.

## Terraform state warning

The current `AIAE-aws-infra` root and backend keys originated with Operational
Hub. They include shared VPC/EKS/Argo resources and application-specific ECR,
IAM, secret, RDS, and frontend resources in the same state.

For a second application:

1. Do not copy the root and point it at a new state; that attempts to duplicate
   the shared platform.
2. Do not rename existing Terraform addresses just to make names generic; that
   can replace live resources.
3. Prefer adding keyed application-scoped resources while retaining current
   addresses, or perform a separate reviewed migration using moved/import/state
   operations with backups and zero-destroy plans.
4. Treat any plan that replaces VPC, EKS, RDS, Argo, OIDC, CodeConnections,
   CloudFront, or Secrets Manager resources as a blocker until explained.

Backend configurations currently use S3 state with native lock files. Always
initialize the exact environment backend before planning.

## Environment safety baseline

Current Operational Hub differences are examples, not universal defaults:

- DEV uses one backend replica; PROD starts with at least two and autoscaling.
- Operational Hub DEV RDS is publicly reachable by explicit business decision;
  PROD RDS is private, Multi-AZ, backed up, and deletion-protected.
- Application logs and managed Prometheus/Grafana are PROD-only in the current
  baseline.
- DNS is managed externally in GoDaddy. Terraform may request ACM certificates,
  but the user or domain administrator must create validation and traffic CNAMEs.

DEV does not use GoDaddy, a custom hostname, or a dedicated ACM certificate by
default. For a frontend, expose the generated CloudFront distribution domain so
a developer can open the application directly. Route its API paths through that
distribution when the application uses one browser origin. For a backend-only
service, use the AWS-generated ALB endpoint. Put those generated origins into
the DEV authentication callback/authorized-party, CORS, and CSP configuration
where required.

Create a DEV custom hostname only when a verified external integration requires
a stable allowlisted callback or webhook URL and the user explicitly approves
the additional DNS/certificate work. This is an application exception, not a
platform onboarding default. The GoDaddy and custom-domain cutover procedure is
otherwise PROD-only.

Default a new application's PROD database to private, protected, backed up, and
Multi-AZ when availability requirements justify it. Public DEV database access
is not an inherited platform rule; require an explicit need and a reviewed
security-group scope.
