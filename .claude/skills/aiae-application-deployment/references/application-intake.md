# Application Intake and Infrastructure Inference

Build this contract from source evidence before writing Terraform, Helm, or
workflows. Do not ask the user to select technical mechanisms that the
repositories and platform rules can determine.

## 1. Repository identity

Record:

| Field | Required evidence |
|---|---|
| Application display name | Repository README or user goal. |
| Application slug | Lowercase DNS-safe name approved for AWS/GitOps names. |
| Source repository | Canonical GitHub `owner/repository`. |
| GitHub numeric organization and repository IDs | GitHub API; required when the organization customizes OIDC subjects. |
| Default development branch | Remote repository metadata. |
| Candidate `X.Y.Z` deployment branch | User release decision plus remote branch check. |
| Deployment unit names | One per independently deployable backend, worker, or frontend. |
| Relationship to existing applications | Same product/API surface, shared data, or independent application in shared EKS. |

Do not infer application coupling only from repository naming. Inspect APIs,
data ownership, authentication, and frontend routing.

## 2. Source analysis

Inspect the complete repository before asking infrastructure questions:

- repository-local agent instructions and build documentation;
- package manifests, Maven/Gradle files, Node package files, lock files;
- Dockerfiles, compose files, Procfiles, `.replit`, `replit.nix`, and scripts;
- application configuration and environment-variable bindings;
- database migrations and startup hooks;
- health/readiness/liveness endpoints;
- frontend build output and runtime API URL handling;
- scheduled tasks, queues, object storage, file uploads, and background workers;
- external APIs and cloud SDK usage;
- authentication issuer, audience, authorized parties, CORS, CSP, and iframe
  requirements;
- logging, metrics, tracing, and actuator endpoints;
- existing CI/CD workflows and branch rules.

Useful evidence searches include environment access (`System.getenv`, Spring
`${...}` placeholders, `process.env`, `import.meta.env`), database URLs, cloud
SDK clients, filesystem writes, bind ports, and health endpoints. Adapt searches
to the actual language and framework.

Classify findings as `required`, `optional`, `local-development-only`,
`legacy-host-only`, or `unknown`.

## 3. Deployment unit contract

Create one record for every deployable unit.

```yaml
application:
  name: Example Application
  slug: example-application
  repository: AiDigital-com/AIAE-example-application
  release_branch: 1.0.0

units:
  - name: example-api
    kind: backend
    build_context: .
    dockerfile: backend/Dockerfile
    container_port: 5000
    health:
      startup: /actuator/health/readiness
      readiness: /actuator/health/readiness
      liveness: /actuator/health/liveness
    public_paths:
      - /api/example/*
    migrations:
      enabled: true
      tool: liquibase-maven
      dockerfile: backend/Liquibase.Dockerfile

  - name: example-web
    kind: static-frontend
    build_directory: frontend
    build_command: npm run build
    output_directory: frontend/dist
```

This is a planning record, not a new source of live configuration. Final values
must live in the owning repositories and AWS services.

## 4. Infrastructure inference matrix

Use source findings to infer resources. Create only rows justified by evidence.

| Evidence | Usually required | Questions or checks |
|---|---|---|
| Containerized HTTP backend | ECR repository, CI OIDC role, Helm Deployment/Service, child Argo Application, ServiceAccount IAM role | Port, health paths, CPU/memory, API paths, AWS permissions. |
| Static React/Vite frontend | Private S3 bucket, CloudFront, origin access control, CI permissions | Build output, SPA routing, API proxy paths, public build config. Use the generated CloudFront domain in DEV; evaluate a custom hostname for PROD. |
| Relational persistence | PostgreSQL database or instance, security groups, secret mapping, backup policy | Data ownership, isolation, extensions, size, availability, DEV access need. |
| Liquibase/Flyway/custom migrations | Separate migration artifact and Argo PreSync Job | Exact command, lock behavior, timeout, rollback compatibility. |
| Runtime secrets | Secrets Manager secret and CSI key mapping | Exact key names, rotation, JSON/multiline handling. |
| BigQuery or Google API | Egress plus service-account JSON secret or workload identity design | Project, dataset, location, least privilege, multiline JSON handling. |
| S3/object uploads | Application-specific bucket and IAM permissions | Retention, size, encryption, public/private, CORS. |
| Scheduled/background processing | Kubernetes CronJob/Deployment or managed scheduler/queue | Concurrency, retries, idempotency, scaling, dead-letter behavior. |
| WebSocket/streaming | ALB/CloudFront behavior and timeout review | Protocol, idle timeout, sticky sessions. |
| PROD public hostname or an explicitly approved DEV hostname exception | CloudFront/ALB routing and ACM certificate | DNS owner, validation method, cutover and rollback records. DEV does not inherit a custom hostname merely because it is browser-accessible. |
| Metrics endpoint | PROD scrape target and dashboard additions | Path, authentication, label cardinality, retention. |
| Application stdout logs | PROD log routing and retention | Sensitive-field redaction and health-probe filtering. |

## 5. Database decision

Determine which model is supported by data ownership:

- **No database**: do not create RDS or migration resources.
- **New database on an approved shared RDS instance**: only when isolation,
  credentials, extensions, capacity, and lifecycle are explicitly supported.
- **Dedicated RDS instance**: use for independent ownership, incompatible
  lifecycle, stronger isolation, or materially different capacity/availability.
- **Existing external database**: record network route, TLS, credentials, and
  operational ownership; do not create a duplicate.

Do not share an Operational Hub schema merely because the new application uses
the same EKS cluster. Kubernetes placement does not imply database ownership.

For PROD, default to private connectivity, backups, deletion protection, and
Multi-AZ according to availability requirements. Never make PROD publicly
reachable for convenience.

## 6. Routing decision

Prefer one product hostname with path-based ALB routing when multiple backends
belong to one user-facing product:

```text
https://product.example/api/service-a/* -> service-a
https://product.example/api/service-b/* -> service-b
```

Use a separate hostname/CloudFront distribution for an independent application
with a separate frontend, authentication origin, lifecycle, or ownership.

Check path rewriting. Kubernetes ALB Ingress routes paths but does not
automatically remove a prefix unless a supported transform is configured. The
backend's controller paths must match what reaches it.

## 7. Configuration inventory

Produce a table before deployment:

| Key | Consumer | DEV value source | PROD value source | Sensitive | Destination |
|---|---|---|---|---|---|
| `EXAMPLE_FLAG` | backend | repository evidence/user | repository evidence/user | no | Helm environment config |
| `EXAMPLE_TOKEN` | backend | user-managed | user-managed | yes | Environment Secrets Manager secret |
| `VITE_PUBLIC_KEY` | frontend build | user-managed | user-managed | public after build | Workflow reads environment config |

Never include secret values in this table. Include exact destination secret
names and required JSON keys.

## 8. Scaling and resilience

Derive requests and limits from measurements when available. Otherwise start
conservatively and record the assumption.

Required decisions:

- DEV replica count;
- PROD minimum and maximum replicas;
- CPU/memory requests and limits;
- rolling-update availability;
- PodDisruptionBudget;
- migration Job deadline/retries;
- database size, Multi-AZ, backup retention, and deletion protection;
- frontend cache behavior;
- ECR retention policy;
- application log and metric retention.

Also record shared-platform admission evidence before deployment:

- currently allocatable versus requested CPU and memory;
- pending/unschedulable Pods and node autoscaler ceiling;
- VPC/subnet IP headroom;
- namespace quotas and limits;
- ALB, listener, target-group, and security-group quota headroom;
- projected application connection pools versus RDS `max_connections`.

Treat a capacity increase as a separate shared-platform change. Do not hide it
inside an application onboarding plan.

Do not copy Operational Hub values without checking the new application's
startup time, memory, connection pool, and traffic model.

## 9. GitHub environment contract

For each environment, list required variables and secrets. Mark values produced
by Terraform outputs and values the user must supply.

The target should normally include:

- AWS OIDC role ARN;
- AWS region;
- application secret name;
- GitOps repository names;
- frontend bucket/distribution only when a frontend exists;
- one DEV deployment branch variable;
- one GitOps repository credential stored as an environment secret.

The role trust must match the organization's actual OIDC subject format. Query
GitHub numeric IDs when custom subject claims include them; do not guess.

## 10. Intake completion gate

The contract is ready only when:

- every deployable unit and build artifact is identified;
- every environment key has a destination and owner;
- database and migration behavior are known;
- public routes and frontend origins are explicit;
- shared versus application-scoped infrastructure is classified;
- DEV/PROD differences are listed;
- manual external actions are listed;
- unknowns that block a safe DEV deployment are resolved.

Unknown sizing may proceed with documented conservative defaults. Unknown
credentials, data ownership, migration behavior, or public routing may not.
