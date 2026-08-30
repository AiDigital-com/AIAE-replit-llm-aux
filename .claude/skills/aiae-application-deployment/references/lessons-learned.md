# AIAE Deployment Lessons Learned

These are verified failure modes from bringing the first AIAE application from
Replit to AWS. Apply them proactively, but still verify the current platform.

## 1. Credentials and 1Password

- AWS CLI/login material and the approved GitHub/GitOps token already exist in
  the team 1Password vault.
- Reuse those items. Do not create new IAM users, long-lived access keys,
  personal access tokens, or SSH credentials as a convenience.
- The deployment agent does not open or query 1Password. It tells the user which
  existing credential is needed, where to enter it, and supplies commands with
  placeholders for local entry.
- Never ask the user to paste a 1Password field into chat.
- If a credential is unavailable or expired, report the item/purpose and stop.
  Credential creation or rotation is an access-management task, not an implicit
  part of application onboarding.
- Application secret values are also user-managed. The deployment agent defines
  the Secrets Manager destination and exact key names, then verifies metadata and
  key presence without returning values.

## 2. GitHub OIDC trust failures

### Symptom

GitHub Actions repeats `Assuming role with OIDC` and ends with
`Not authorized to perform sts:AssumeRoleWithWebIdentity`.

### Cause already observed

The organization uses a customized GitHub OIDC subject containing numeric
organization and repository IDs, not only `repo:owner/name:environment:dev`.

The known shape is:

```text
repo:<organization>@<organization-id>/<repository>@<repository-id>:environment:<environment>
```

### Prevention

- Query actual organization and repository IDs through authenticated GitHub API.
- Put explicit `dev` and `prod` subjects in the corresponding Terraform inputs.
- Confirm the workflow job uses the matching GitHub environment.
- Inspect the rendered IAM trust policy before rerunning the workflow.
- Do not weaken trust to all branches or repositories to make the error disappear.

The Node runtime deprecation warning from an action is not the cause of an OIDC
authorization failure. Read the terminal error, not only warnings above it.

## 3. ECR permissions are wider than a simple upload

### Failures already observed

- Buildx push denied on `ecr:BatchGetImage`.
- PROD release denied on `ecr:DescribeImages`.

### Required workflow capabilities

The CI role may need:

- `ecr:GetAuthorizationToken` on all resources;
- repository-scoped `DescribeRepositories` or account-level read as required;
- `BatchCheckLayerAvailability`;
- `BatchGetImage`;
- `CompleteLayerUpload`;
- `InitiateLayerUpload`;
- `PutImage`;
- `UploadLayerPart`;
- `DescribeImages` for release discovery/retention;
- `BatchDeleteImage` only when the approved retention workflow deletes old tags.

Keep permissions scoped to the application's ECR repository except operations
that AWS requires on `*`.

## 4. GitOps token organization approval

### Symptom

The workflow builds and pushes images, then receives HTTP 403 while updating
`AIAE-helm-versions` or `AIAE-helm`.

### Causes already observed

- Fine-grained token request was still waiting for organization-admin approval.
- The token identity had no write permission to the target repository.

### Prevention

- Retrieve the existing approved token from 1Password; do not create another.
- Confirm organization approval is complete.
- Confirm selected repository access includes both GitOps repositories.
- Confirm `Contents: Read and write` is granted.
- Store it as the application repository's environment secret, not as a plain
  variable.
- Validate access without printing the token.

## 5. Shared GitOps repositories create race conditions

Every application writes to the same `AIAE-helm-versions/main` and environment
branches. Two workflows can both clone an old head, modify different files, and
race during publication.

Prevention:

- use application-specific workflow concurrency for duplicate releases;
- do not rely on repository-local concurrency for cross-application locking;
  GitHub concurrency groups do not span source repositories;
- use a bounded optimistic publication loop: fetch the latest GitOps head,
  reapply only this application's change, publish fast-forward-only, and retry
  from the new remote head on non-fast-forward;
- touch only the application's own version file and environment fields;
- never replace the whole services map from a stale checkout;
- after publication, confirm both applications' entries still exist.

## 6. ECR image identity and retention

The working model uses immutable commit-qualified tags:

- DEV: `X.Y.Z-snapshot-<commit>` and matching migration image;
- PROD: `X.Y.Z-<commit>` and matching migration image.

Lessons:

- `X.Y.Z` alone is ambiguous while development continues.
- Rebuilding the same commit is unnecessary; reuse the immutable artifact.
- Keep application and migration images as a pair.
- DEV lifecycle policy may retain a bounded number of snapshot pairs.
- PROD rollback requires at least one complete previous pair plus frontend
  release metadata. Do not delete a previous version merely because a newer
  semantic version exists.
- A manual rollback should select an existing artifact; it should not rebuild an
  old commit.

## 7. Terraform shared-resource trap

The first Terraform root created both platform-wide and application-specific
resources. Copying it for a second app would attempt another VPC, EKS cluster,
Argo capability, OIDC provider, and other shared resources.

Lessons:

- inspect the saved state and plan, not only source files;
- classify shared versus application-scoped resources before implementation;
- preserve existing Terraform addresses unless a reviewed migration is planned;
- a large create count can be correct for the first environment but is suspicious
  for adding one app to an existing cluster;
- `terraform apply` should use the reviewed saved plan;
- S3 native lock files are used; a DynamoDB lock table is not required by the
  current backend;
- ordinary workload redeployment must not replace RDS. Any database replacement
  in a plan is a blocker unless explicitly intended and backed up.

Terraform can remove resources predictably, but PROD deletion protection,
backups, final snapshots, and external DNS mean destruction is not a casual
rollback mechanism.

## 8. CodeConnections handshake

AWS can create a GitHub CodeConnections resource in `PENDING` state, but Argo CD
cannot use it until a human authorizes the GitHub App connection in the AWS
Console.

Check status explicitly. When pending, direct the user to the connection's
`Update pending connection` flow and wait for `AVAILABLE`. Do not recreate the
connection repeatedly.

## 9. Argo CD root and child model

There is one root Application per environment and one child Application per
deployable backend.

- `aiae-dev-root` and `aiae-prod-root` are environment catalogs.
- A new backend gets its own child; it does not get another root merely because
  it is an independent product.
- Frontends deployed to S3/CloudFront do not appear as Kubernetes resources in
  Argo CD.
- A stale incorrectly named root can remain visible even when the correct root
  works. Delete it only after proving it is unmanaged and no longer owns live
  resources.
- Healthy means resources operate; Synced means live Kubernetes matches Git.
  Check both.

## 10. Namespace and naming drift

Early iterations used application-specific namespaces and root names. The final
shared model uses `aiae-dev`, `aiae-prod`, `aiae-dev-root`, and `aiae-prod-root`.

When adding an app, search every chart, Application template, Terraform access
scope, service-account subject, and Argo destination. A single old namespace can
break IAM, secret projection, or reconciliation.

Do not rename the physical EKS cluster merely because its historical name still
contains `operational-hub`; that is a separate infrastructure migration.

## 11. Secrets Manager mapping

The application consumes one environment-neutral property name per setting.
DEV and PROD separation comes from separate secret objects and Helm branches,
not `PRD_` duplicates inside the application.

Database connection keys required by the current migration/chart pattern are:

```text
POSTGRES_HOST
POSTGRES_PORT
POSTGRES_DB
POSTGRES_USER
POSTGRES_PASSWORD
```

Other keys must come from source analysis. For Operational Hub they included
Clerk and Google service-account fields, but those are not universal.

When RDS is recreated intentionally, update the application secret mapping and
verify migration connectivity before rollout. Do not output the generated RDS
password.

Changing an authentication tenant can invalidate stored external user IDs. Any
cleanup is a business-data migration: back up first, scope the SQL precisely,
and require explicit authorization.

## 12. Database network access

RDS `publicly_accessible=true` alone does not make a database reachable. The
subnet route, security group, network ACL, DNS, and client source CIDR must all
permit it.

The first DEV database initially allowed one external `/32`; a changed client IP
then failed. Broad `0.0.0.0/0` access was an explicit temporary business choice,
not a recommended default.

For every new app:

- ask whether direct DEV access is genuinely required;
- prefer VPN, SSM tunnel, bastion, or a restricted CIDR;
- never expose PROD RDS publicly;
- distinguish application connectivity from developer connectivity.

## 13. Liquibase ordering

Automatic application-startup migrations were disabled. The deployment uses a
separate Argo PreSync Job so schema migration succeeds before new pods roll out.

Lessons:

- do not run Maven from the application pod unless that is the reviewed image
  contract;
- the migration image must contain the Maven project and changelogs;
- use the exact release-paired migration tag;
- read database values from Secrets Store CSI;
- make the Job visible in Argo events/logs;
- a failed migration stops rollout;
- rollback safety depends on backward-compatible schema changes.

## 14. ALB, ACM, CloudFront, and DNS

### Failures already observed

- Argo deploy model reported no certificate for a host.
- ALB listener creation failed because HTTPS had no certificate.
- Custom production hostname remained on the old provider until GoDaddy records
  propagated.

### Correct dependency order

1. Request the certificate in the correct region. CloudFront certificates must
   be in `us-east-1`.
2. Give the DNS administrator the exact ACM validation CNAME host and value.
3. Wait for ACM `ISSUED`.
4. Attach the certificate/custom hostname to CloudFront or ALB as designed.
5. Verify the AWS-generated endpoint first.
6. Replace the old traffic record with the CloudFront CNAME.
7. Preserve the ACM validation CNAME.
8. Check public DNS from multiple resolvers, TLS certificate, frontend, API,
   login, and rollback before retiring the old host.

A/ TXT records used by a previous hosting provider are not copied to AWS. The
AWS traffic record is normally a CNAME to CloudFront for the current external
DNS model.

### One-step versus two-step GoDaddy cutover

A single administrator change is safe only when an already issued certificate
in `us-east-1` covers the final hostname and CloudFront is already deployed with
that hostname as an alias. In that case the administrator changes only the
traffic CNAME.

This CNAME flow applies to a subdomain such as `app.example.com`. For a zone
apex such as `example.com`, confirm that the DNS provider supports apex
flattening/ALIAS-like behavior; otherwise use a subdomain or an explicitly
reviewed provider-specific record. Never send an impossible apex CNAME request.

When no reusable issued certificate exists, two DNS actions are required:

1. add and retain the ACM validation CNAME;
2. after ACM is `ISSUED` and CloudFront is configured/tested, replace the old
   traffic record with the CloudFront CNAME.

Do not ask an administrator to perform both actions immediately in one visit.
The traffic record could move before CloudFront recognizes the hostname and has
valid TLS. The skill may put both planned steps into one ticket/message, but must
label the second as `WAIT FOR PLATFORM READY CONFIRMATION`.

Before traffic cutover, record the current traffic records and TTL. When
possible, ask the DNS owner to lower TTL at least one prior TTL interval before
the cutover. Define a rollback threshold and message in advance, for example
rollback on persistent TLS failure, 5xx increase, or failed login/API smoke
tests during the agreed observation window.

## 15. Frontend and API routing

The React frontend is built by GitHub Actions and deployed to S3/CloudFront, so
it is not represented by pods in Argo CD.

CloudFront can present one browser origin and forward `/api/*` to the ALB. ALB
Ingress can then route different API prefixes to different Kubernetes Services.
This avoids exposing multiple backend origins to the browser.

Check that each backend accepts the path it receives. Routing does not imply
prefix rewriting.

## 16. Logging and metrics

The agreed baseline is:

- application stdout collection to CloudWatch in PROD only;
- short CloudWatch retention;
- health/readiness/liveness probes excluded from verbose Logbook request logs;
- managed Prometheus and Grafana in PROD only;
- HTTP latency histograms/SLO buckets enabled when percentile panels require
  them;
- application/API, JVM, HikariCP, PostgreSQL, application cache, and external
  query metrics selected intentionally;
- no Kubernetes, node, ALB/CloudFront, deployment-marker, or CloudWatch Logs
  dashboards by default;
- no paid CloudFront additional metrics subscription unless a verified
  incident-response requirement justifies its recurring cost;
- low-cardinality labels only.

Per-pod panels are still possible when metrics are scraped centrally; include
pod/instance labels in queries rather than deploying a Prometheus per pod.

Managed Grafana users come from the organization IAM Identity Center. Member
account users may be visible in one console yet fail workspace association when
they are not provisioned in the organization instance. This requires the
organization administrator; do not attempt to work around it with unrelated
local accounts.

Do not create a Grafana service account, API user, or API token to import,
update, or delete dashboards. Amazon Managed Grafana can bill every such
identity as an active editor for the billing month even when it is immediately
deleted. Use the Grafana UI as an already assigned administrator. If no existing
administrator can perform the change, stop and ask the organization
administrator to assign one; do not create a temporary identity as a shortcut.

Before adding a new exporter, scrape target, dashboard, custom CloudWatch
metric, or log query, explain the operational question it answers and estimate
its recurring ingestion, storage, query, and user-license cost. Keep the
existing application and PostgreSQL baseline when the additional signal is
duplicated elsewhere or is only useful for presentation.

## 17. A deployment is not one green job

Completion requires the chain to agree:

1. source revision;
2. GitHub workflow result;
3. ECR application/migration artifact tags;
4. frontend release files;
5. versions repository values;
6. environment branch pinned versions revision;
7. Argo child source revisions;
8. successful migration Job;
9. healthy rollout and pods;
10. service/ingress/ALB target health;
11. CloudFront/frontend/API behavior;
12. login, database, logs, and metrics.

Always report the first boundary where evidence stops.
